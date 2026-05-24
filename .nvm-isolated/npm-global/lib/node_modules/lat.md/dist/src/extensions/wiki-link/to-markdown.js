/**
 * mdast-util extension to serialize wiki-link nodes back to markdown.
 */
function handler(node, _parent, state, _info) {
    const exit = state.enter('wikiLink');
    const target = state.safe(node.value, { before: '[', after: ']' });
    let value;
    if (node.data.alias) {
        const alias = state.safe(node.data.alias, { before: '[', after: ']' });
        value = `[[${target}|${alias}]]`;
    }
    else {
        value = `[[${target}]]`;
    }
    exit();
    return value;
}
export function wikiLinkToMarkdown() {
    return {
        unsafe: [
            { character: '[', inConstruct: ['phrasing', 'label', 'reference'] },
            { character: ']', inConstruct: ['label', 'reference'] },
        ],
        handlers: {
            wikiLink: handler,
        },
    };
}
