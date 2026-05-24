import type { Section } from './lattice.js';
export type SourceSymbol = {
    name: string;
    kind: 'function' | 'class' | 'const' | 'type' | 'interface' | 'method' | 'variable';
    parent?: string;
    startLine: number;
    endLine: number;
    signature: string;
};
/** All source file extensions that lat can parse (derived from grammarMap). */
export declare const SOURCE_EXTENSIONS: ReadonlySet<string>;
export declare function parseSourceSymbols(filePath: string, content: string): Promise<SourceSymbol[]>;
/** Clear the symbol cache. Call between top-level operations. */
export declare function clearSymbolCache(): void;
/**
 * Check whether a source file path (relative to projectRoot) has a given symbol.
 * Used by lat check to validate source code wiki links lazily.
 */
export declare function resolveSourceSymbol(filePath: string, symbolPath: string, projectRoot: string): Promise<{
    found: boolean;
    symbols: SourceSymbol[];
    error?: string;
}>;
/**
 * Convert source symbols to Section objects for uniform handling.
 */
export declare function sourceSymbolsToSections(symbols: SourceSymbol[], filePath: string): Section[];
