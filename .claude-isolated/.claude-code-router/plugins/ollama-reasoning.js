'use strict';

/**
 * CCR transformer: copies delta.reasoning → delta.content for Ollama reasoning models.
 * Applied before the built-in `reasoning` transformer (place last in `use` array —
 * CCR applies use[] in reverse order).
 */
class OllamaReasoningTransformer {
  constructor(options) {
    this.name = 'ollama-reasoning';
    this.options = options || {};
  }

  _transformSseLine(line) {
    if (!line.startsWith('data: ')) return line;
    const data = line.slice(6);
    if (data === '[DONE]') return line;
    let parsed;
    try {
      parsed = JSON.parse(data);
    } catch {
      return line;
    }
    let modified = false;
    for (const choice of parsed?.choices ?? []) {
      if (choice.delta !== undefined) {
        const r = choice.delta.reasoning || choice.delta.reasoning_content || '';
        if (r && !choice.delta.content) {
          choice.delta.content = r;
          modified = true;
        }
      }
    }
    return modified ? 'data: ' + JSON.stringify(parsed) : line;
  }

  async transformResponseOut(response) {
    const ct = response?.headers?.get?.('Content-Type') || '';

    if (ct.includes('text/event-stream') && response.body) {
      const self = this;
      const dec = new TextDecoder();
      const enc = new TextEncoder();
      let buf = '';

      const xform = new TransformStream({
        transform(chunk, ctrl) {
          buf += dec.decode(chunk, { stream: true });
          const nl = buf.lastIndexOf('\n');
          if (nl >= 0) {
            const complete = buf.slice(0, nl + 1);
            buf = buf.slice(nl + 1);
            const out = complete
              .split('\n')
              .map(line => self._transformSseLine(line))
              .join('\n');
            ctrl.enqueue(enc.encode(out));
          }
        },
        flush(ctrl) {
          if (buf) {
            const out = buf
              .split('\n')
              .map(line => self._transformSseLine(line))
              .join('\n');
            ctrl.enqueue(enc.encode(out));
          }
        }
      });

      return new Response(response.body.pipeThrough(xform), {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
      });
    }

    if (ct.includes('application/json')) {
      const json = await response.json();
      for (const choice of json?.choices ?? []) {
        if (choice.message !== undefined) {
          const r = choice.message.reasoning || choice.message.reasoning_content || '';
          if (r && !choice.message.content) choice.message.content = r;
        }
      }
      return new Response(JSON.stringify(json), {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
      });
    }

    return response;
  }
}

module.exports = OllamaReasoningTransformer;
