import { join, relative } from 'node:path';
import { loadAllSections, findSections, } from '../lattice.js';
const WIKI_LINK_RE = /\[\[([^\]]+)\]\]/g;
function formatLocation(section, projectRoot) {
    const relPath = relative(process.cwd(), join(projectRoot, section.filePath));
    return `${relPath}:${section.startLine}-${section.endLine}`;
}
/**
 * Resolve [[refs]] in text and return the expanded output.
 * Returns null if there are no wiki links, or if resolution fails.
 */
export async function expandPrompt(ctx, text) {
    const refs = [...text.matchAll(WIKI_LINK_RE)];
    if (refs.length === 0)
        return null;
    const allSections = await loadAllSections(ctx.latDir);
    const resolved = new Map();
    const errors = [];
    for (const match of refs) {
        const target = match[1];
        if (resolved.has(target))
            continue;
        const matches = findSections(allSections, target);
        if (matches.length >= 1) {
            resolved.set(target, {
                target,
                best: matches[0],
                alternatives: matches.slice(1),
            });
        }
        else {
            errors.push(`No section found for [[${target}]]`);
        }
    }
    if (errors.length > 0)
        return null;
    // Replace [[refs]] inline
    let output = text.replace(WIKI_LINK_RE, (_match, target) => {
        const ref = resolved.get(target);
        return `[[${ref.best.section.id}]]`;
    });
    // Append context block as nested outliner
    output += '\n\n<lat-context>\n';
    for (const ref of resolved.values()) {
        const isExact = ref.best.reason === 'exact match' ||
            ref.best.reason.startsWith('file stem expanded');
        const all = isExact ? [ref.best] : [ref.best, ...ref.alternatives];
        if (isExact) {
            output += `* \`[[${ref.target}]]\` is referring to:\n`;
        }
        else {
            output += `* \`[[${ref.target}]]\` might be referring to either of the following:\n`;
        }
        for (const m of all) {
            const reason = isExact ? '' : ` (${m.reason})`;
            output += `  * [[${m.section.id}]]${reason}\n`;
            output += `    * ${formatLocation(m.section, ctx.projectRoot)}\n`;
            if (m.section.firstParagraph) {
                output += `    * ${m.section.firstParagraph}\n`;
            }
        }
    }
    output += '</lat-context>\n';
    return output;
}
export async function expandCommand(ctx, text) {
    const result = await expandPrompt(ctx, text);
    if (result === null) {
        const refs = [...text.matchAll(WIKI_LINK_RE)];
        if (refs.length === 0) {
            return { output: text };
        }
        // Resolution failed — find which ref is broken
        const allSections = await loadAllSections(ctx.latDir);
        for (const match of refs) {
            const target = match[1];
            const matches = findSections(allSections, target);
            if (matches.length === 0) {
                const s = ctx.styler;
                return {
                    output: s.red(`No section found for [[${target}]]`) +
                        ' (no exact, substring, or fuzzy matches).\n' +
                        s.dim('Ask the user to correct the reference.'),
                    isError: true,
                };
            }
        }
        // All refs matched individually but expansion still failed — shouldn't happen
        return { output: text };
    }
    return { output: result };
}
