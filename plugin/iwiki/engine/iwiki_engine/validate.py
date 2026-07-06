"""Deterministic section-formation checks over a wiki page — stdlib only, no API.

Mirrors the structural rules the authoring skills mandate (see the section-formation
spec). Consumed by ``lint`` (folded into its report) and the ``validate`` subcommand.
The blocking subset (deep_heading, pre_h2_text) is mirrored inline by the
iwiki-validate PreToolUse hook; the advisory subset (missing_overview, missing_lead,
long_lead) is report-only.
"""
from __future__ import annotations
import re

OVERVIEW_HEADING = "overview"   # keep in sync with chunk.OVERVIEW_HEADING
LEAD_MAX = 250                  # keep in sync with chunk.LEAD_MAX

_DEEP = re.compile(r"^#{3,}\s", re.MULTILINE)   # ### or deeper
_H1_LINE = re.compile(r"^#\s+\S")               # a single-# H1 line
_H2 = re.compile(r"^##\s+(.*?)\s*$", re.MULTILINE)   # keep in sync with chunk._H2


def _sections(content: str) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    ms = list(_H2.finditer(content))
    for i, m in enumerate(ms):
        start = m.end()
        end = ms[i + 1].start() if i + 1 < len(ms) else len(content)
        out.append((m.group(1).strip(), content[start:end].strip()))
    return out


def _lead(body: str) -> str:
    para: list[str] = []
    for ln in body.splitlines():
        if not ln.strip():
            if para:
                break
            continue
        para.append(ln.strip())
    return " ".join(para)


def validate_page(content: str) -> list[dict]:
    """Return a list of {type, severity, text} section-formation findings."""
    findings: list[dict] = []

    if _DEEP.search(content):
        findings.append({"type": "deep_heading", "severity": "block",
                         "text": "heading deeper than ## (###+); flatten to ##"})

    h2 = _H2.search(content)
    pre = content[:h2.start()] if h2 else content
    if any(ln.strip() and not _H1_LINE.match(ln) for ln in pre.splitlines()):
        findings.append({"type": "pre_h2_text", "severity": "block",
                         "text": "indexable text before the first ## (only a single # H1 allowed)"})

    secs = _sections(content)
    if not secs or secs[0][0].lower() != OVERVIEW_HEADING:
        findings.append({"type": "missing_overview", "severity": "advisory",
                         "text": "first ## section is not 'Overview'"})

    for heading, body in secs:
        lead = _lead(body)
        if not lead:
            findings.append({"type": "missing_lead", "severity": "advisory",
                             "text": f"section '{heading}' has no lead paragraph"})
        elif len(lead) > LEAD_MAX:
            findings.append({"type": "long_lead", "severity": "advisory",
                             "text": f"section '{heading}' lead exceeds {LEAD_MAX} chars"})
    return findings
