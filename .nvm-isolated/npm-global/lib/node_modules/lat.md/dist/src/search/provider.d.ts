export type EmbeddingProvider = {
    name: string;
    apiBase: string;
    model: string;
    dimensions: number;
    headers: (key: string) => Record<string, string>;
};
export declare function detectProvider(key: string): EmbeddingProvider;
