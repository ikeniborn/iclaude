// @ts-expect-error -- no type declarations
import walk from 'ignore-walk';
/**
 * Walk a directory tree respecting .gitignore rules. Returns relative paths
 * of all non-ignored files, excluding .git/ and dotfiles (e.g. .gitignore).
 *
 * This is the single entry point for all directory walking in lat.md — both
 * code-ref scanning and lat.md/ index validation use it so .gitignore rules
 * are consistently honored.
 */
export function walkEntries(dir) {
    return walk({
        path: dir,
        ignoreFiles: ['.gitignore'],
    }).then((entries) => entries.filter((e) => !e.startsWith('.git/') && !e.startsWith('.')));
}
