import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
/**
 * Bump this number whenever `lat init` setup changes in a way that
 * requires users to re-run it (e.g. new hooks, AGENTS.md changes,
 * MCP config changes).
 */
export const INIT_VERSION = 1;
function cachePath(latDir) {
    return join(latDir, '.cache', 'lat_init.json');
}
function readMeta(latDir) {
    const p = cachePath(latDir);
    if (!existsSync(p))
        return null;
    try {
        return JSON.parse(readFileSync(p, 'utf-8'));
    }
    catch {
        return null;
    }
}
export function readInitVersion(latDir) {
    const meta = readMeta(latDir);
    if (!meta)
        return null;
    return typeof meta.init_version === 'number' ? meta.init_version : null;
}
export function readFileHash(latDir, relPath) {
    const meta = readMeta(latDir);
    return meta?.file_hashes?.[relPath] ?? null;
}
export function contentHash(content) {
    return createHash('sha256').update(content).digest('hex');
}
export function writeInitMeta(latDir, fileHashes) {
    const cacheDir = join(latDir, '.cache');
    mkdirSync(cacheDir, { recursive: true });
    // Merge with existing hashes so we don't lose entries from agents
    // that weren't selected this run
    const existing = readMeta(latDir);
    const mergedHashes = { ...existing?.file_hashes, ...fileHashes };
    const data = {
        init_version: INIT_VERSION,
        file_hashes: mergedHashes,
    };
    writeFileSync(cachePath(latDir), JSON.stringify(data, null, 2) + '\n');
}
