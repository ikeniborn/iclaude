// Framework OpenAI Chat does not accept CCR's Anthropic thinking translation.
module.exports = class FrameworkRequest {
  name = 'framework-request';

  transformRequestIn(request) {
    delete request.reasoning;
    // CCR emits empty descriptions for MCP tools without documentation;
    // Framework accepts an omitted description but rejects an empty string.
    for (const tool of request.tools || []) {
      if (tool.function?.description === '') {
        delete tool.function.description;
      }
    }
    return request;
  }
};
