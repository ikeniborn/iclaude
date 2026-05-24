/**
 * Walk a directory tree respecting .gitignore rules. Returns relative paths
 * of all non-ignored files, excluding .git/ and dotfiles (e.g. .gitignore).
 *
 * This is the single entry point for all directory walking in lat.md — both
 * code-ref scanning and lat.md/ index validation use it so .gitignore rules
 * are consistently honored.
 */
export declare function walkEntries(dir: string): Promise<string[]>;
