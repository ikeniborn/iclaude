const assert = require('node:assert/strict');
const Transformer = require('../.claude-isolated/.claude-code-router/plugins/framework-request.js');
const transformer = new Transformer();
const request = {
  model: 'ollama-glm-5-3-cloud',
  messages: [{role: 'user', content: 'Call a function'}],
  tools: [{type: 'function', function: {name: 'probe'}}],
  tool_choice: {type: 'function', function: {name: 'probe'}},
  stream: true, max_tokens: 8192,
  reasoning: {enabled: false, effort: 'high'},
};
const expected = {...request};
delete expected.reasoning;
const output = transformer.transformRequestIn(request);
assert.deepEqual(output, expected);
assert.deepEqual(transformer.transformRequestIn({...expected}), expected);
const mcpRequest = {
  tools: [
    {type: 'function', function: {name: 'wiki_status', description: ''}},
    {type: 'function', function: {name: 'wiki_read_page', description: 'Read a page'}},
  ],
};
const mcpOutput = transformer.transformRequestIn(mcpRequest);
assert.equal(Object.hasOwn(mcpOutput.tools[0].function, 'description'), false);
assert.equal(mcpOutput.tools[1].function.description, 'Read a page');
console.log('Framework request compatibility: PASS');
