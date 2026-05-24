/**
 * mdast-util extension to turn wiki-link micromark tokens into mdast nodes.
 */
function enterWikiLink(token) {
    const node = {
        type: 'wikiLink',
        value: '',
        data: { alias: null },
    };
    this.enter(node, token);
}
function exitWikiLinkTarget(token) {
    const target = this.sliceSerialize(token);
    const node = this.stack[this.stack.length - 1];
    node.value = target;
}
function exitWikiLinkAlias(token) {
    const alias = this.sliceSerialize(token);
    const node = this.stack[this.stack.length - 1];
    node.data.alias = alias;
}
function exitWikiLink(token) {
    this.exit(token);
}
export function wikiLinkFromMarkdown() {
    return {
        enter: { wikiLink: enterWikiLink },
        exit: {
            wikiLinkTarget: exitWikiLinkTarget,
            wikiLinkAlias: exitWikiLinkAlias,
            wikiLink: exitWikiLink,
        },
    };
}
