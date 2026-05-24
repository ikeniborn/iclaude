/**
 * Micromark syntax extension for wiki links: [[target]] and [[target|alias]].
 *
 * Produces the following token types:
 *   - wikiLink          (the entire construct)
 *   - wikiLinkMarker    ([[ and ]])
 *   - wikiLinkData      (everything between markers)
 *   - wikiLinkTarget    (the target portion)
 *   - wikiLinkAliasMarker (the | divider)
 *   - wikiLinkAlias     (the alias portion)
 */
import type { Extension } from 'micromark-util-types';
import './types.js';
export declare function wikiLinkSyntax(): Extension;
