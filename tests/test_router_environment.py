"""Exercise launcher and installed CCR without model or GitLab network calls."""
import json
import os
from pathlib import Path
import subprocess
import shlex
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RouterEnvironmentTests(unittest.TestCase):
    def test_ccr_child_keeps_user_home_and_proxy_exclusions(self):
        self.run_router({"NO_PROXY": "gitlab.example.com,localhost",
                         "no_proxy": "gitlab.example.com,localhost"},
                        "gitlab.example.com,localhost,127.0.0.1")

    def test_lowercase_only_and_custom_claude_command(self):
        self.run_router({"no_proxy": "gitlab.example.com"},
                        "gitlab.example.com,127.0.0.1", custom_command=True)

    def test_empty_exclusions_still_bypass_router_loopback(self):
        self.run_router({}, "127.0.0.1")

    def test_launcher_initialization_preserves_lowercase_no_proxy(self):
        source = (ROOT / "iclaude.sh").read_text()
        initialization = source.split("    test_mode=false", 1)[1].split("    claude_args=()", 1)[0]
        result = subprocess.run(["bash", "-c", initialization + '\nprintenv no_proxy'],
                                env=dict(os.environ, no_proxy="gitlab.example.com"),
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), "gitlab.example.com")

    def run_router(self, exclusions, expected, custom_command=False):
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            home = tmp / "user home"
            store = tmp / "store"
            (home / ".config/glab-cli").mkdir(parents=True)
            (home / ".config/glab-cli/config.yml").write_text("fixture credential location\n")
            (store / ".claude-code-router").mkdir(parents=True)
            (tmp / "nvm").mkdir()
            (tmp / "bin").mkdir()
            recorder = tmp / "bin/claude"
            recorder.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
value = args[args.index('--settings') + 1]
settings = json.loads(value if value.startswith('{') else pathlib.Path(value).read_text())
os.environ.update(settings.get('env', {}))
pathlib.Path(os.environ['CAPTURE']).write_text(json.dumps({
    'home': os.environ['HOME'], 'no_proxy': os.environ.get('NO_PROXY'),
    'lowercase': os.environ.get('no_proxy'), 'args': args,
    'config': (pathlib.Path.home() / '.config/glab-cli/config.yml').read_text()
    if (pathlib.Path.home() / '.config/glab-cli/config.yml').exists() else None,
    'base_url': os.environ.get('ANTHROPIC_BASE_URL')
}))
sys.exit(7)
''')
            recorder.chmod(0o755)
            # CCR only requires a live PID to reuse a server. No HTTP request is made.
            server = subprocess.Popen(["sleep", "60"])
            try:
                (store / ".claude-code-router/.claude-code-router.pid").write_text(str(server.pid))
                (store / "router.json").write_text(json.dumps({"PORT": 3456, "Providers": [], "Router": {}}))
                node_dirs = sorted((ROOT / ".nvm-isolated/versions/node").glob("v2*/bin"))
                env = dict(os.environ, HOME=str(home), TMPDIR=str(tmp),
                           CAPTURE=str(tmp / "capture.json"), PATH=str(tmp / "bin") + ":" +
                           str(node_dirs[-1]) + ":" + os.environ["PATH"],
                           FIXTURE=str(tmp), STORE=str(store), ROOT=str(ROOT))
                env.pop("CLAUDE_PATH", None)
                env.pop("NO_PROXY", None)
                env.pop("no_proxy", None)
                env.update(exclusions)
                if custom_command:
                    env["CLAUDE_PATH"] = "python3 " + shlex.quote(str(recorder))
                script = '''
source "$ROOT/lib/launcher/launch.sh"
source "$ROOT/lib/router/detect.sh"
print_info() { :; }; print_warning() { :; }; print_error() { echo "$*" >&2; }
cleanup_stale_session_env() { :; }
detect_router() { return 0; }
get_router_path() { printf '%s' "$ROOT/.nvm-isolated/npm-global/bin/ccr"; }
export USE_ROUTER_FLAG=true ISOLATED_CONFIG_DIR="$STORE" CLAUDE_CONFIG_DIR="$STORE"
export ISOLATED_NVM_DIR="$FIXTURE/nvm" LIB_DIR="$ROOT/lib"
launch_claude false --print 'prompt with spaces'
'''
                result = subprocess.run(["bash", "-c", script], env=env, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 7, result.stderr)
                data = json.loads((tmp / "capture.json").read_text())
                self.assertEqual(data["home"], str(home))
                self.assertEqual(data["no_proxy"], expected)
                self.assertEqual(data["lowercase"], expected)
                self.assertEqual(data["config"], "fixture credential location\n")
                self.assertEqual(data["base_url"], "http://127.0.0.1:3456")
                self.assertEqual(data["args"][:2], ["--print", "prompt with spaces"])
            finally:
                server.terminate()
                server.wait()


if __name__ == "__main__":
    unittest.main()
