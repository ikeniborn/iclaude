# install

> **Module:** `pii-proxy` | **File:** `lib/pii-proxy/install.sh`

PII-Proxy installation module
Provides function for installing Presidio NLP dependencies

---

## `install_isolated_pii_proxy`

Install PII-proxy to isolated environment. **Idempotent**: skips steps that are already up to date.

**Arguments:**

-   `$1` *(optional)* — `"--force"`: remove existing venv and reinstall all components unconditionally

**Idempotency checks (skipped if already done):**

| Step | Check | Savings |
|------|-------|---------|
| venv | `$PII_PROXY_VENV/bin/python3` executable + version ≥ 3.8 | venv recreate + pip upgrade |
| Presidio packages | `pip show presidio-analyzer presidio-anonymizer spacy` | ~100MB pip install |
| spaCy `en_core_web_lg` | `spacy.load('en_core_web_lg')` succeeds | **587MB download** |
| spaCy `en_core_web_sm` | fallback: `spacy.load('en_core_web_sm')` succeeds | 12MB download |
| Server script | `diff -q src dst` matches | file copy + chmod |

**Returns:**

-   0 - success (fresh install or already up to date)
-   1 - error

