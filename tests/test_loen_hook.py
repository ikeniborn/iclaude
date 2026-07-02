#!/usr/bin/env python3
"""Unit tests for the loen loop-guard PreToolUse hook.
Exit 0 = allow, exit 2 = block. The hook reads tool_input.file_path from stdin JSON
and enforces layout/naming under docs/loen/ plus scope from the active loop.yaml."""
import json, os, subprocess, sys, tempfile, textwrap

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "loop-guard.py")


def run(cwd, file_path, tool="Write"):
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": file_path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd)
    return p.returncode


def setup_run(root, run_id="2026-07-01-demo", mutable=("src/*",), protected=("datasets/*",), flow=False):
    d = os.path.join(root, "docs", "loen", run_id)
    os.makedirs(os.path.join(d, "iterations"), exist_ok=True)
    with open(os.path.join(d, "loop.yaml"), "w") as f:
        if flow:  # inline flow-style lists
            f.write("mutable_scope: [%s]\n" % ", ".join(mutable))
            f.write("protected_scope: [%s]\n" % ", ".join(protected))
        else:      # block-style lists
            f.write("mutable_scope:\n")
            for g in mutable:
                f.write(f"  - {g}\n")
            f.write("protected_scope:\n")
            for g in protected:
                f.write(f"  - {g}\n")
    cur = os.path.join(root, "docs", "loen", "current")
    if os.path.islink(cur):
        os.unlink(cur)
    os.symlink(run_id + "/", cur)
    return run_id


def main():
    fails = []
    def check(name, got, want):
        if got != want:
            fails.append(f"{name}: got exit {got}, want {want}")

    with tempfile.TemporaryDirectory() as root:
        # no active loop -> non-loen path allowed (no-op)
        check("no-loop non-loen allow", run(root, os.path.join(root, "src/app.py")), 0)
        # no active loop -> write under docs/loen (not the pointer) blocked
        check("no-loop loen-artifact block",
              run(root, os.path.join(root, "docs/loen/2026-07-01-demo/loop.yaml")), 2)
        # bootstrap: setting the current pointer is always allowed
        check("bootstrap current allow", run(root, os.path.join(root, "docs/loen/current")), 0)

        R = setup_run(root)
        base = os.path.join(root, "docs", "loen", R)
        # canonical artifact -> allow
        check("canonical loop.yaml", run(root, os.path.join(base, "loop.yaml")), 0)
        check("canonical iter file",
              run(root, os.path.join(base, "iterations/iter-01/verifier.md")), 0)
        # malformed iteration name -> block
        check("bad iter name",
              run(root, os.path.join(base, "iterations/iter-1/verifier.md")), 2)
        # non-canonical loen path -> block
        check("non-canonical loen", run(root, os.path.join(base, "notes.txt")), 2)
        # cross-topic write -> block
        check("cross-topic",
              run(root, os.path.join(root, "docs/loen/2026-07-01-other/loop.yaml")), 2)
        # scope: mutable allowed, protected blocked, out-of-scope blocked
        check("mutable allow", run(root, os.path.join(root, "src/app.py")), 0)
        check("protected block", run(root, os.path.join(root, "datasets/raw.csv")), 2)
        check("out-of-scope block", run(root, os.path.join(root, "lib/x.sh")), 2)

        # inline flow-style scope must be enforced too
        setup_run(root, run_id="2026-07-01-flow", mutable=("lib/*",), protected=("secrets/*",), flow=True)
        check("flow mutable allow", run(root, os.path.join(root, "lib/x.sh")), 0)
        check("flow protected block", run(root, os.path.join(root, "secrets/k")), 2)

    if fails:
        print("FAIL test_loen_hook.py")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("PASS test_loen_hook.py")


if __name__ == "__main__":
    main()
