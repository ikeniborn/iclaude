/** Walk project files for code-ref scanning. Uses walkEntries for .gitignore
 *  support, then additionally skips .md files, lat.md/, .claude/, and sub-projects. */
export declare function walkFiles(dir: string): Promise<string[]>;
export declare const LAT_REF_RE: RegExp;
export type CodeRef = {
    target: string;
    file: string;
    line: number;
};
export type ScanResult = {
    refs: CodeRef[];
    files: string[];
    usedRg: boolean;
};
/** Check whether ripgrep (`rg`) is available on PATH. */
export declare function hasRipgrep(): Promise<boolean>;
export declare function scanCodeRefs(projectRoot: string): Promise<ScanResult>;
