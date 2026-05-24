import { type Section, type SectionMatch } from '../lattice.js';
import type { CmdContext, CmdResult } from '../context.js';
export type Scope = 'md' | 'code' | 'md+code';
export type RefsFound = {
    kind: 'found';
    target: Section;
    mdRefs: SectionMatch[];
    codeRefs: string[];
};
export type RefsError = {
    kind: 'no-match';
    suggestions: SectionMatch[];
};
export type RefsResult = RefsFound | RefsError;
/**
 * Find all sections and code locations that reference a given section or
 * source file. Accepts section ids (full-path, short-form) and source file
 * paths (e.g. src/app.rs#foo). Source file queries match wiki links directly
 * without section resolution.
 */
export declare function findRefs(ctx: CmdContext, query: string, scope: Scope): Promise<RefsResult>;
export declare function refsCommand(ctx: CmdContext, query: string, scope: Scope): Promise<CmdResult>;
