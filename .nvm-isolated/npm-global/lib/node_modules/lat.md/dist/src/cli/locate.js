import { loadAllSections, findSections } from '../lattice.js';
import { formatResultList } from '../format.js';
export async function locateCommand(ctx, query) {
    const stripped = query.replace(/^\[\[|\]\]$/g, '');
    const sections = await loadAllSections(ctx.latDir);
    const matches = findSections(sections, stripped);
    if (matches.length === 0) {
        const s = ctx.styler;
        return {
            output: s.red(`No sections matching "${stripped}" (no exact, substring, or fuzzy matches)`),
            isError: true,
        };
    }
    return {
        output: formatResultList(ctx, `Sections matching "${stripped}":`, matches),
    };
}
