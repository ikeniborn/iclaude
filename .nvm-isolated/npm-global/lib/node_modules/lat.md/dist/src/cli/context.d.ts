import type { CmdContext } from '../context.js';
export type { CmdContext };
export declare function resolveContext(opts: {
    dir?: string;
    color?: boolean;
}): CmdContext;
