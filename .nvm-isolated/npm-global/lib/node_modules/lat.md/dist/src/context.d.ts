export type Styler = {
    bold: (s: string) => string;
    dim: (s: string) => string;
    red: (s: string) => string;
    cyan: (s: string) => string;
    white: (s: string) => string;
    green: (s: string) => string;
    yellow: (s: string) => string;
    boldWhite: (s: string) => string;
};
export declare const plainStyler: Styler;
export type CmdContext = {
    latDir: string;
    projectRoot: string;
    styler: Styler;
    mode: 'cli' | 'mcp';
};
export type CmdResult = {
    output: string;
    isError?: boolean;
};
