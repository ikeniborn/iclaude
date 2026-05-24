import type { Root } from 'mdast';
export declare function parse(markdown: string): Root;
export declare function toMarkdown(tree: Root): string;
