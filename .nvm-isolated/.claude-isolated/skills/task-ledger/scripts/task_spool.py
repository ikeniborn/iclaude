#!/usr/bin/env python3
"""Redacted, local delivery spool for parent-owned iwiki task events."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
import tempfile
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import Any

VALID_KINDS = {
    "open", "route", "dispatch", "return", "decision", "blocker", "verification", "gate", "close",
}
_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_HASH = re.compile(r"^[0-9a-f]{16,64}$")
_SECRET = re.compile(
    r"(?:\b(?:[a-z0-9_-]*(?:api[-_]?key|token|secret|access[-_]?key|client[-_]?secret|private[-_]?key)|"
    r"authorization|password|credential)\b\s*[:=]|\bBearer\s+\S+)", re.I
)
_RFC3339_Z = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
_SECRET_PATH_COMPONENTS = {"auth", "authentication", "token", "tokens", "credential", "credentials"}
_SECRET_FILE_COMPONENT = re.compile(
    r"^(?:auth(?:entication)?|token|tokens|credential|credentials)\.(?:json|ya?ml|txt|conf|ini)$|"
    r"^(?:private[-_]?key|access[-_]?key|access[-_]?token|client[-_]?secret)(?:\.[a-z0-9]+)?$",
    re.I,
)


def _require_slug(value: str, label: str) -> None:
    if not _SLUG.fullmatch(value):
        raise ValueError(f"{label} must be lowercase kebab-case")


def _require_keys(value: dict[str, Any], keys: set[str], label: str) -> None:
    if set(value) != keys:
        raise ValueError(f"{label} has unknown or missing keys")


def _safe_text(value: object, label: str, maximum: int = 250) -> str:
    if not isinstance(value, str) or not value or len(value) > maximum:
        raise ValueError(f"{label} must be a short single-line string")
    if any(unicodedata.category(char).startswith("C") or char in {"\u2028", "\u2029"} for char in value):
        raise ValueError(f"{label} contains a control character")
    if _SECRET.search(value):
        raise ValueError(f"{label} contains sensitive data")
    return value


def validate_event(value: object, topic: str) -> dict[str, object]:
    """Validate and return a redacted event with only the public schema."""
    _require_slug(topic, "topic")
    if not isinstance(value, dict):
        raise ValueError("event must be an object")
    _require_keys(value, {"kind", "occurred_at", "actor", "summary", "evidence"}, "event")
    kind = value["kind"]
    if not isinstance(kind, str) or kind not in VALID_KINDS:
        raise ValueError("invalid event kind")
    occurred_at = value["occurred_at"]
    if not isinstance(occurred_at, str) or not _RFC3339_Z.fullmatch(occurred_at):
        raise ValueError("occurred_at must be RFC3339 UTC")
    try:
        datetime.strptime(occurred_at, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise ValueError("occurred_at must be RFC3339 UTC") from exc
    actor = _safe_text(value["actor"], "actor", 100)
    summary = _safe_text(value["summary"], "summary")
    evidence = value["evidence"]
    if not isinstance(evidence, dict):
        raise ValueError("evidence must be an object")
    _require_keys(evidence, {"paths", "checks", "hashes"}, "evidence")
    paths = evidence["paths"]
    checks = evidence["checks"]
    hashes = evidence["hashes"]
    if not isinstance(paths, list) or not isinstance(checks, list) or not isinstance(hashes, dict):
        raise ValueError("invalid evidence fields")
    valid_paths: list[str] = []
    for path in paths:
        if not isinstance(path, str) or not path or len(path) > 512 or path.startswith("/") or "\\" in path:
            raise ValueError("paths must be repository-relative")
        parts = path.split("/")
        if (
            any(
                part in {"", ".", ".."}
                or part.lower().startswith(".env")
                or part.lower() in _SECRET_PATH_COMPONENTS
                or _SECRET_FILE_COMPONENT.fullmatch(part) is not None
                for part in parts
            )
            or _SECRET.search(path)
            or any(unicodedata.category(char).startswith("C") or char in {"\u2028", "\u2029"} for char in path)
        ):
            raise ValueError("paths must be safe repository-relative paths")
        valid_paths.append(path)
    valid_checks: list[dict[str, object]] = []
    for check in checks:
        if not isinstance(check, dict):
            raise ValueError("checks must contain objects")
        _require_keys(check, {"name", "status", "exit_code"}, "check")
        name = _safe_text(check["name"], "check name", 160)
        status = check["status"]
        exit_code = check["exit_code"]
        if status not in {"passed", "failed"} or not isinstance(exit_code, int) or isinstance(exit_code, bool):
            raise ValueError("invalid check")
        valid_checks.append({"name": name, "status": status, "exit_code": exit_code})
    valid_hashes: dict[str, str] = {}
    for name, digest in hashes.items():
        if not isinstance(name, str) or not _SLUG.fullmatch(name):
            raise ValueError("hash names must be lowercase kebab-case")
        if not isinstance(digest, str) or not _HASH.fullmatch(digest):
            raise ValueError("hashes must be lowercase hexadecimal")
        valid_hashes[name] = digest
    canonical_evidence = {"paths": valid_paths, "checks": valid_checks, "hashes": valid_hashes}
    evidence_digest = hashlib.sha256(
        json.dumps(canonical_evidence, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return {
        "kind": kind,
        "occurred_at": occurred_at,
        "actor": actor,
        "summary": summary,
        "evidence": canonical_evidence,
        "evidence_hash": evidence_digest,
    }


def event_id(topic: str, event: dict[str, object]) -> str:
    """Return stable ID derived solely from topic, kind, canonical evidence."""
    _require_slug(topic, "topic")
    evidence_hash = event["evidence_hash"]
    if not isinstance(evidence_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", evidence_hash):
        raise ValueError("event must carry canonical evidence_hash")
    material = f"{topic}\n{event['kind']}\n{evidence_hash}".encode()
    return hashlib.sha256(material).hexdigest()[:16]


def _queue_path(config_dir: Path, project: str, topic: str) -> Path:
    _require_slug(project, "project")
    _require_slug(topic, "topic")
    return config_dir / "state" / "iwiki-task-spool" / project / f"{topic}.json"


def _ensure_queue_parent(path: Path) -> None:
    """Create and validate only real directories from the config dir to the queue parent."""
    current = path.parents[3]
    components = (current, current / "state", current / "state" / "iwiki-task-spool", path.parent)
    for index, component in enumerate(components):
        try:
            mode = os.lstat(component).st_mode
        except FileNotFoundError:
            component.mkdir(mode=0o700)
            mode = os.lstat(component).st_mode
        if (
            not stat.S_ISDIR(mode)
            or stat.S_ISLNK(mode)
            or (index >= 2 and (os.lstat(component).st_uid != os.getuid() or mode & 0o077))
        ):
            raise ValueError("spool directory must be a real directory")


def _validate_queue_parent(path: Path) -> None:
    current = path.parents[3]
    components = (current, current / "state", current / "state" / "iwiki-task-spool", path.parent)
    for index, component in enumerate(components):
        try:
            mode = os.lstat(component).st_mode
        except FileNotFoundError:
            return
        if (
            not stat.S_ISDIR(mode)
            or stat.S_ISLNK(mode)
            or (index >= 2 and (os.lstat(component).st_uid != os.getuid() or mode & 0o077))
        ):
            raise ValueError("spool directory must be a real directory")


def _validate_target(path: Path) -> None:
    try:
        mode = os.lstat(path).st_mode
    except FileNotFoundError:
        return
    if os.path.islink(path) or not stat.S_ISREG(mode):
        raise ValueError("spool target must be a regular file")


def _fsync_directory(directory: Path) -> None:
    descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _load(path: Path, project: str, topic: str) -> dict[str, object]:
    _validate_queue_parent(path)
    _validate_target(path)
    if not path.exists():
        return {"schema_version": 1, "project": project, "topic": topic, "events": []}
    with path.open(encoding="utf-8") as stream:
        queue = json.load(stream)
    if not isinstance(queue, dict) or set(queue) != {"schema_version", "project", "topic", "events"}:
        raise ValueError("invalid spool queue")
    if type(queue["schema_version"]) is not int or queue["schema_version"] != 1:
        raise ValueError("schema_version must be integer 1")
    if queue["project"] != project or queue["topic"] != topic:
        raise ValueError("spool queue identity mismatch")
    if not isinstance(queue["events"], list):
        raise ValueError("invalid spool events")
    for stored in queue["events"]:
        if not isinstance(stored, dict):
            raise ValueError("invalid spool event")
        _require_keys(
            stored,
            {"kind", "occurred_at", "actor", "summary", "evidence", "evidence_hash", "event_id"},
            "spool event",
        )
        raw = {key: stored[key] for key in ("kind", "occurred_at", "actor", "summary", "evidence")}
        validated = validate_event(raw, topic)
        if stored["evidence_hash"] != validated["evidence_hash"] or stored["event_id"] != event_id(topic, validated):
            raise ValueError("spool event integrity mismatch")
    return queue


def _write(path: Path, queue: dict[str, object]) -> None:
    _ensure_queue_parent(path)
    _validate_target(path)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(queue, stream, sort_keys=True, separators=(",", ":"))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        _fsync_directory(path.parent)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def enqueue(config_dir: Path, project: str, topic: str, event: dict[str, object]) -> str:
    """Append an event once and atomically replace its private queue file."""
    validated = validate_event(event, topic)
    identifier = event_id(topic, validated)
    path = _queue_path(config_dir, project, topic)
    queue = _load(path, project, topic)
    events = queue["events"]
    assert isinstance(events, list)
    if any(isinstance(item, dict) and item.get("event_id") == identifier for item in events):
        return identifier
    stored = dict(validated)
    stored["event_id"] = identifier
    events.append(stored)
    _write(path, queue)
    return identifier


def list_events(config_dir: Path, project: str, topic: str) -> dict[str, object]:
    """Return local queue state without changing it."""
    return _load(_queue_path(config_dir, project, topic), project, topic)


def acknowledge(config_dir: Path, project: str, topic: str, acknowledged_id: str) -> None:
    """Remove exactly one confirmed event; remove an empty queue file."""
    path = _queue_path(config_dir, project, topic)
    queue = _load(path, project, topic)
    events = queue["events"]
    assert isinstance(events, list)
    kept = [item for item in events if not (isinstance(item, dict) and item.get("event_id") == acknowledged_id)]
    if len(kept) != len(events) - 1:
        raise ValueError("event_id must identify exactly one queued event")
    if kept:
        queue["events"] = kept
        _write(path, queue)
    else:
        _validate_target(path)
        path.unlink()
        _fsync_directory(path.parent)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("enqueue", "list", "ack"))
    parser.add_argument("--config-dir", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--topic", required=True)
    parser.add_argument("--event-id")
    args = parser.parse_args()
    config_dir = Path(args.config_dir)
    try:
        if args.command == "enqueue":
            if args.event_id:
                raise ValueError("enqueue does not accept event_id")
            event = json.load(sys.stdin)
            print(json.dumps({"event_id": enqueue(config_dir, args.project, args.topic, event)}))
        elif args.command == "list":
            if args.event_id:
                raise ValueError("list does not accept event_id")
            print(json.dumps(list_events(config_dir, args.project, args.topic), sort_keys=True))
        else:
            if not args.event_id:
                raise ValueError("ack requires --event-id")
            acknowledge(config_dir, args.project, args.topic, args.event_id)
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
        print(f"task_spool: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
