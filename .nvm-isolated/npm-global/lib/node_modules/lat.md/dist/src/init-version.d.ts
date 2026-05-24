/**
 * Bump this number whenever `lat init` setup changes in a way that
 * requires users to re-run it (e.g. new hooks, AGENTS.md changes,
 * MCP config changes).
 */
export declare const INIT_VERSION = 1;
export declare function readInitVersion(latDir: string): number | null;
export declare function readFileHash(latDir: string, relPath: string): string | null;
export declare function contentHash(content: string): string;
export declare function writeInitMeta(latDir: string, fileHashes: Record<string, string>): void;
