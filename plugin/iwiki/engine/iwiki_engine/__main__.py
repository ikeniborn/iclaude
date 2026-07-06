"""iwiki-engine CLI: index | search | related | status."""
from __future__ import annotations
import argparse
import glob
import json
import os
import sys

from .config import Config, ConfigError
from .chunk import chunk_markdown
from .embed import embed_texts, EmbedError
from .store import (make_record, load_index, save_index, index_bytes)
from .search import search as do_search
from .related import related as do_related
from .lint import lint as do_lint

CAP_BYTES = 8 * 1024 * 1024


def _index_path(wiki_dir: str) -> str:
    return os.path.join(wiki_dir, ".iwiki", "index.jsonl")


def cmd_index(cfg: Config, wiki_dir: str) -> int:
    path = _index_path(wiki_dir)
    existing = {r.id + f"#{r.chunk}": r for r in load_index(path)}
    chunks = []
    files = sorted(glob.glob(os.path.join(wiki_dir, "**", "*.md"), recursive=True))
    files = [f for f in files if "/.iwiki/" not in f]
    if cfg.ignore is not None:
        files = [f for f in files if not cfg.ignore.match_file(f)]
    for md in files:
        content = open(md, encoding="utf-8").read()
        chunks.extend(chunk_markdown(md, content, cfg.chunk_size,
                                     cfg.chunk_overlap, cfg.summary_max))
    fresh, reused, to_embed = [], 0, []
    for c in chunks:
        key = c.id + f"#{c.chunk}"
        prev = existing.get(key)
        if prev and prev.hash == c.hash:
            fresh.append(prev)
            reused += 1
        else:
            to_embed.append(c)
    if to_embed:
        vecs = embed_texts(cfg, [c.text for c in to_embed])
        fresh.extend(make_record(c, v) for c, v in zip(to_embed, vecs))
    fresh.sort(key=lambda r: (r.file, r.heading, r.chunk))
    save_index(path, fresh)
    size = index_bytes(path)
    warn = "  WARNING: index exceeds 8 MB cap" if size > CAP_BYTES else ""
    print(f"indexed: {len(fresh)} chunks ({reused} reused, {len(to_embed)} embedded), "
          f"{size} bytes{warn}")
    return 0


def cmd_search(cfg: Config, wiki_dir: str, query: str, k: int | None,
               threshold: float | None) -> int:
    recs = load_index(_index_path(wiki_dir))
    qv = embed_texts(cfg, [query])[0]
    res = do_search(qv, recs, k or cfg.top_k, threshold if threshold is not None
                    else cfg.score_threshold)
    print(json.dumps(res, ensure_ascii=False))
    return 0


def cmd_related(cfg: Config, wiki_dir: str, section_id: str) -> int:
    recs = load_index(_index_path(wiki_dir))
    print(json.dumps(do_related(section_id, recs, cfg.top_k, cfg.graph_depth),
                     ensure_ascii=False))
    return 0


def cmd_lint(wiki_dir: str) -> int:
    print(json.dumps(do_lint(wiki_dir), ensure_ascii=False))
    return 0


def cmd_validate(wiki_dir: str) -> int:
    from .validate import validate_page
    files = sorted(glob.glob(os.path.join(wiki_dir, "**", "*.md"), recursive=True))
    files = [f for f in files if "/.iwiki/" not in f]
    out = []
    for p in files:
        try:
            c = open(p, encoding="utf-8").read()
        except Exception:
            continue
        out += [{"page": p, **f} for f in validate_page(c)]
    print(json.dumps({"sections": out}, ensure_ascii=False))
    return 0


def cmd_status(wiki_dir: str) -> int:
    recs = load_index(_index_path(wiki_dir))
    size = index_bytes(_index_path(wiki_dir))
    files = sorted({r.file for r in recs})
    print(json.dumps({"chunks": len(recs), "files": len(files),
                      "bytes": size, "over_cap": size > CAP_BYTES}, ensure_ascii=False))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(prog="iwiki-engine")
    p.add_argument("--wiki-dir", default="docs/wiki")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("index")
    sp = sub.add_parser("search")
    sp.add_argument("query")
    sp.add_argument("-k", type=int, default=None)
    sp.add_argument("--threshold", type=float, default=None)
    rp = sub.add_parser("related")
    rp.add_argument("section_id")
    sub.add_parser("status")
    sub.add_parser("lint")
    sub.add_parser("validate")
    args = p.parse_args()
    try:
        if args.cmd == "status":
            return cmd_status(args.wiki_dir)
        if args.cmd == "lint":
            return cmd_lint(args.wiki_dir)
        if args.cmd == "validate":
            return cmd_validate(args.wiki_dir)
        cfg = Config.load()
        if args.cmd == "index":
            return cmd_index(cfg, args.wiki_dir)
        if args.cmd == "search":
            return cmd_search(cfg, args.wiki_dir, args.query, args.k, args.threshold)
        if args.cmd == "related":
            return cmd_related(cfg, args.wiki_dir, args.section_id)
    except (ConfigError, EmbedError) as e:
        print(f"iwiki-engine: HALT: {e}", file=sys.stderr)
        return 2
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
