import type { CmdContext, CmdResult } from '../context.js';
export type CheckError = {
    file: string;
    line: number;
    target: string;
    message: string;
};
/** File counts grouped by extension (e.g. { ".ts": 5, ".py": 2 }). */
export type FileStats = Record<string, number>;
export type CheckResult = {
    errors: CheckError[];
    files: FileStats;
};
export declare function checkMd(latticeDir: string): Promise<CheckResult>;
export declare function checkCodeRefs(latticeDir: string): Promise<CheckResult>;
export type IndexError = {
    dir: string;
    message: string;
    snippet?: string;
};
export declare function checkIndex(latticeDir: string): Promise<IndexError[]>;
export declare function checkSections(latticeDir: string): Promise<CheckError[]>;
export declare function checkAllCommand(ctx: CmdContext): Promise<CmdResult>;
export declare function checkMdCommand(ctx: CmdContext): Promise<CmdResult>;
export declare function checkCodeRefsCommand(ctx: CmdContext): Promise<CmdResult>;
export declare function checkIndexCommand(ctx: CmdContext): Promise<CmdResult>;
export declare function checkSectionsCommand(ctx: CmdContext): Promise<CmdResult>;
