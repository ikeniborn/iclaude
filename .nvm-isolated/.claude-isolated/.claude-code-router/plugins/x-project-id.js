// CCR transformer plugin — injects X-Project-Id into the upstream request to the provider.
// CCR 2.0.0 drops provider-config `headers` at registerProvider, so the ONLY way to add an
// outgoing header is a transformer that returns `config.headers` from transformRequestIn —
// the same mechanism the built-in `gemini` transformer uses for `x-goog-api-key`.
// The value comes from process.env.ICLAUDE_PROJECT_ID, which lib/launcher/launch.sh exports
// before CCR starts (R2). LiteLLM's project_tagger turns it into the Langfuse tag project:<id>.
module.exports = class XProjectId {
  name = "x-project-id";

  transformRequestIn(request, provider) {
    return {
      body: request,
      config: {
        headers: { "X-Project-Id": process.env.ICLAUDE_PROJECT_ID || "unknown" },
      },
    };
  }
};
