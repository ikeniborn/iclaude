import { type Section, type SectionMatch } from '../lattice.js';
import type { CmdContext, CmdResult } from '../context.js';
export type CodeBackRef = {
    file: string;
    line: number;
    snippet: string;
};
export type SourceRef = {
    target: string;
    file: string;
    line: number;
    endLine: number;
    snippet: string;
};
export type SectionFound = {
    kind: 'found';
    section: Section;
    content: string;
    outgoingRefs: {
        target: string;
        resolved: Section;
    }[];
    outgoingSourceRefs: SourceRef[];
    incomingRefs: SectionMatch[];
    codeRefs: CodeBackRef[];
};
export type SectionResult = SectionFound | {
    kind: 'no-match';
    suggestions: SectionMatch[];
};
/**
 * Look up a section by id, return its content, outgoing wiki link targets,
 * and incoming references from other sections.
 */
export declare function getSection(ctx: CmdContext, query: string): Promise<SectionResult>;
/**
 * Format a successful section result with styling.
 */
export declare function formatSectionOutput(ctx: CmdContext, result: SectionFound): string;
export declare function sectionCommand(ctx: CmdContext, query: string): Promise<CmdResult>;
