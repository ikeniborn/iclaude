import type { CmdContext, CmdResult } from '../context.js';
/**
 * Resolve [[refs]] in text and return the expanded output.
 * Returns null if there are no wiki links, or if resolution fails.
 */
export declare function expandPrompt(ctx: CmdContext, text: string): Promise<string | null>;
export declare function expandCommand(ctx: CmdContext, text: string): Promise<CmdResult>;
