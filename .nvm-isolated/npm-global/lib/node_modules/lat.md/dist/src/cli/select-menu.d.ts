export interface SelectOption {
    label: string;
    value: string;
    /** If true, this option uses a distinct highlight style (e.g. for "done" actions). */
    accent?: boolean;
}
/**
 * Display an interactive select menu with arrow-key navigation.
 * Returns the selected option's value, or null if the user pressed Ctrl+C.
 *
 * @param defaultIndex - initial cursor position (defaults to 0)
 */
export declare function selectMenu(options: SelectOption[], prompt?: string, defaultIndex?: number): Promise<string | null>;
