# Spec: Per-Project Tagging of Claude Code LLM Traffic in Langfuse

**Version:** 1.0 (draft)
**Date:** 2026-06-21
**Status:** R1 (provider `headers`) verified DEAD in CCR 2.0.0 — dropped at `registerProvider`; R2 (`ICLAUDE_PROJECT_ID` export) implemented in launch.sh; R3 (transformer plugin) is now the PRIMARY forwarding mechanism — pending implementation. Empirical proof: `tests/test_x_project_id_forwarding.sh`.
**Owner:** iclaude
**Related:** minipc Langfuse deploy (`docs/langfuse/guide.md` in the minipc repo)

---

## 1. Goal

Attribute Claude Code LLM traffic in self-hosted Langfuse **per project** instead of the
current `project:unknown`. After this change, each trace produced by a CC session must
carry the tag `project:<repo-name>` (the repo/dir CC was launched in).

Measured baseline (2026-06-21, minipc ClickHouse): of 62 traces, **2** `project:minipc`
(manual smoke), **58** `project:unknown` — i.e. all real CC/agent traffic is untagged.

## 2. Background — data flow

```
Claude Code  ──►  PII proxy (USE_PII_PROXY=true, masks secrets)  ──►  CCR (:3456)
   ──►  LiteLLM (homelab.ikeniborn.ru, MY_PROVIDER_URL)  ──►  Ollama
                         │
                         └─►  langfuse success_callback  ──►  Langfuse / ClickHouse
```

- The Langfuse trace is created by **LiteLLM** (native `langfuse` callback). LiteLLM's
  `project_tagger` pre-call hook (minipc repo, `docs/litellm/project_tagger.py`) reads the
  **`X-Project-Id` request header** and emits the tag `project:<value>` (default `unknown`).
- **No LiteLLM-side change is needed.** The only missing piece is that nothing in the
  CC → CCR → LiteLLM chain sends `X-Project-Id`. CCR is the component that talks to LiteLLM,
  so the header must be injected at **CCR → LiteLLM**.
- CCR is started **per CC launch** (`start_ccr_server` in `lib/launcher/launch.sh`), so a
  per-launch environment variable propagates to the right CCR instance.

## 3. Current state (already applied — reversible)

- `router.json` (`.nvm-isolated/.claude-isolated/router.json`): the `homelab` provider now
  has `"headers": { "X-Project-Id": "${ICLAUDE_PROJECT_ID}" }`.
  Backup: `router.json.bak-pre-xproject-*`.
- **Not yet done:** `ICLAUDE_PROJECT_ID` is not exported at launch → the header currently
  interpolates to empty. Harmless (empty header → `project:unknown`), but inert until R2.
- **Unverified:** whether CCR 2.0.0 forwards a provider-level `headers` map to the upstream
  request (see R3 fallback if it does not).

## 4. Requirements

### R1 — CCR provider header (primary)  ❌ VERIFIED DEAD in CCR 2.0.0

`router.json` `homelab` provider carries:
```jsonc
"headers": { "X-Project-Id": "${ICLAUDE_PROJECT_ID}" }
```
**Outcome: this does NOT work in CCR 2.0.0.** Verified empirically (`tests/test_x_project_id_forwarding.sh`
fails; negative control with a literal wrong value fails identically → the header is dropped
entirely, not mis-valued) and confirmed in the bundled source (`dist/cli.js`):
- The config IS deep-interpolated (`Fh` walker substitutes `${ICLAUDE_PROJECT_ID}` from
  `process.env` across the whole config tree, including nested `headers`).
- BUT `registerProvider({name, baseUrl, apiKey, models, transformer})` **never passes `t.headers`** —
  the provider's `headers` field is discarded at registration. The `...t?.headers` spread in the
  upstream request build refers to the *request* headers (incoming + transformer-injected), not the
  provider config. So the interpolated value is computed and then thrown away.

The `headers` block is harmless (inert) but ineffective. The fix is **R3** (transformer plugin),
which is the only mechanism in CCR 2.0.0 that can inject a header into the upstream request.

### R2 — per-project `ICLAUDE_PROJECT_ID` at launch  ⏳ TODO

In `lib/launcher/launch.sh`, before CCR is started (`start_ccr_server` and the
`exec ccr code` path), export the project id derived from the launch directory:
```bash
# Per-project attribution for Langfuse (CCR forwards it as X-Project-Id → LiteLLM project_tagger)
if [[ -z "${ICLAUDE_PROJECT_ID:-}" ]]; then
  ICLAUDE_PROJECT_ID="$(basename "$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")"
  export ICLAUDE_PROJECT_ID
fi
```
Notes:
- Derive from the **git toplevel** (repo name); fall back to `basename "$PWD"` for non-git dirs.
- Sanitize to a tag-safe value (lowercase, `[a-z0-9._-]`, strip spaces) if repo names can be exotic.
- Must be exported **before** the CCR process forks. If the microVM / PII-proxy chain is
  active, confirm the variable propagates through to the CCR process (the PII proxy and
  microVM wrappers must pass it through — verify per `lib/sandbox/microvm.sh` and the PII
  proxy launch).
- Optional: allow an explicit override (`ICLAUDE_PROJECT_ID` already set in env / `.claude_config`
  wins, e.g. for a fixed project name).

### R3 — CCR transformer plugin (PRIMARY mechanism — R1 is dead)

Inject `X-Project-Id` via a CCR transformer plugin. This is the **only** working mechanism in
CCR 2.0.0. The plugin returns `config.headers` from `transformRequestIn`; CCR merges those into
the upstream request (confirmed in `dist/cli.js`: the `auth`/transformer path does
`h = {...h, ...c.config.headers}` and `t = {...t, ...c.config, headers: h}` before building the
upstream `{Authorization, ...t.headers}` object — the same path the built-in `gemini` transformer
uses to set `x-goog-api-key`).

**Correct shape for CCR 2.0.0** (the earlier skeleton's `request.headers[...]=...; return request`
shape does NOT work — CCR ignores a mutated `request.headers`; it reads `config.headers` from the
return value):
```js
// .claude-code-router/plugins/x-project-id.js
module.exports = class XProjectId {
  name = "x-project-id";
  // transformRequestIn(request, provider) → { body, config: { headers } }.
  // CCR merges config.headers into the outgoing request to the provider.
  transformRequestIn(request, provider) {
    return {
      body: request,
      config: { headers: { "X-Project-Id": process.env.ICLAUDE_PROJECT_ID || "unknown" } },
    };
  }
};
```
Register it in `router.json`: add `"x-project-id"` to the `homelab` provider's `transformer.use`
array, and add `{ "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/x-project-id.js" }` to
the top-level `transformers` list (alongside `ollama-reasoning.js`). R2 still required: the plugin
reads `process.env.ICLAUDE_PROJECT_ID`, which `_init_project_id()` exports before CCR starts.

The provider-level `headers` block (R1) can stay (inert) or be removed; it has no effect either way.

### R4 — Last resort: LiteLLM virtual keys per project

Create a LiteLLM virtual key per project with `metadata.project`, and have iclaude select
the matching key (`MY_PROVIDER_API_KEY`). LiteLLM attributes the request from the key's
metadata; `project_tagger` (or the langfuse callback) reads it. More setup (key management +
per-project selection in iclaude), no CCR change. Only if R1–R3 all fail.

## 5. Verification / acceptance

1. Launch CC via iclaude in a known repo (e.g. `~/Documents/Project/minipc`) with `--router`.
2. Send any message (one LLM call).
3. On the minipc host, query Langfuse ClickHouse:
   ```bash
   docker exec minipc-traefik-clickhouse-1 sh -c \
     'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" -q \
      "SELECT tags FROM traces ORDER BY timestamp DESC LIMIT 1"'
   ```
   **Accept** when the newest trace contains `project:minipc` (the repo name), not
   `project:unknown`.
4. Repeat from a different repo → tag reflects that repo's name (proves per-project).

## 6. Related hardening (out of scope here — note for backlog)

- **Secret in plaintext:** `MY_PROVIDER_API_KEY` (== the LiteLLM master_key) is stored in
  cleartext in `.claude_config` and has leaked into CC session transcripts (`*.jsonl`) and
  VS Code history. Move to a secret store / keyring; rotate the LiteLLM master_key after.
- **Privacy:** Langfuse stores the **full** prompt + completion (code, file contents — whatever
  CC sends); only credential patterns (`sk-`/`Bearer`/`ghp_`/`AKIA`) are masked by LiteLLM's
  `project_tagger` masking function. The PII proxy (`USE_PII_PROXY=true`, `MASKING_LEVEL=secrets`)
  masks secrets earlier in the chain. Decide whether prompt bodies in Langfuse are acceptable
  for the homelab threat model; if not, raise the PII proxy masking level or disable Langfuse
  input/output capture.
- **Other clients:** OpenWebUI and standalone scripts that hit LiteLLM also show as
  `project:unknown`. Each needs its own `X-Project-Id` (OpenWebUI connection header, script
  header). Out of scope for this iclaude spec.

## 7. Rollback

- `router.json`: restore `router.json.bak-pre-xproject-*` (removes the `headers` block).
- `launch.sh`: revert the `ICLAUDE_PROJECT_ID` export.
- No LiteLLM/Langfuse-side change was made for this feature, so nothing to roll back there.
