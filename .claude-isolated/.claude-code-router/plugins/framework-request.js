// Framework OpenAI Chat does not accept CCR's Anthropic thinking translation.
module.exports = class FrameworkRequest {
  name = 'framework-request';

  transformRequestIn(request) {
    delete request.reasoning;
    return request;
  }
};
