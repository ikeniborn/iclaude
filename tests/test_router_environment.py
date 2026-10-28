"""Exercise launcher and installed CCR without model or GitLab network calls."""
import json
import os
from pathlib import Path
import subprocess
import shlex
import signal
import socket
import tempfile
import time
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

    def test_repeated_mcp_configs_keep_exact_arguments(self):
        self.run_router({}, "127.0.0.1", complex_args="mcp")

    def test_repeated_configs_and_user_settings_keep_exact_arguments(self):
        self.run_router({}, "127.0.0.1", complex_args=True)

    def test_cold_start_daemon_does_not_inherit_original_arguments(self):
        self.run_router({}, "127.0.0.1", complex_args=True, cold_start=True)

    def test_failed_ccr_launch_does_not_leave_pipe_writer(self):
        self.run_router({}, "127.0.0.1", failed_launch=True)

    def test_empty_argument_list(self):
        self.run_router({}, "127.0.0.1", empty_args=True)

    def run_router(self, exclusions, expected, custom_command=False, complex_args=False,
                   cold_start=False, empty_args=False, failed_launch=False):
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
value = args[len(args) - 1 - args[::-1].index('--settings') + 1]
settings = json.loads(value if value.startswith('{') else pathlib.Path(value).read_text())
os.environ.update(settings.get('env', {}))
daemon_pid = int((pathlib.Path(os.environ['STORE']) / '.claude-code-router/.claude-code-router.pid').read_text())
daemon_env = pathlib.Path(f'/proc/{daemon_pid}/environ').read_bytes()

pathlib.Path(os.environ['CAPTURE']).write_text(json.dumps({
    'home': os.environ['HOME'], 'no_proxy': os.environ.get('NO_PROXY'),
    'transport_removed': 'ICLAUDE_ROUTER_CLAUDE_ARGS_PIPE' not in os.environ,
    'daemon_has_argv': b'ICLAUDE_ROUTER_CLAUDE_ARGS=' in daemon_env,
    'daemon_has_prompt': b'prompt with spaces' in daemon_env,

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
                port = 3456
                if cold_start:
                    with socket.socket() as probe:
                        probe.bind(("127.0.0.1", 0))
                        port = probe.getsockname()[1]
                else:
                    (store / ".claude-code-router/.claude-code-router.pid").write_text(str(server.pid))
                (store / "router.json").write_text(json.dumps({"PORT": port, "Providers": [], "Router": {}}))
                node_dirs = sorted((ROOT / ".nvm-isolated/versions/node").glob("v2*/bin"))
                env = dict(os.environ, HOME=str(home), TMPDIR=str(tmp),
                           CAPTURE=str(tmp / "capture.json"), PATH=str(tmp / "bin") + ":" +
                           str(node_dirs[-1]) + ":" + os.environ["PATH"],
                           FIXTURE=str(tmp), STORE=str(store), ROOT=str(ROOT),
                           ICLAUDE_ROUTER_CLAUDE_ARGS="stale inherited transport")
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
                original = [] if empty_args else ["--print", "prompt with spaces"]
                if empty_args:
                    script = script.replace("launch_claude false --print 'prompt with spaces'", "launch_claude false")
                if complex_args:
                    original += ["--mcp-config", '{"mcpServers":{"fixture":{"command":"fixture command"}}}',
                                 "--mcp-config", str(tmp / "iwiki runtime.json"),
                                 "--mcp-config", "user config.json"]
                    if complex_args != "mcp":
                        original += ["--settings", '{"model":"fixture"}',
                                     "--settings", "user settings.json", "positional prompt", ""]
                    script = script.replace("launch_claude false --print 'prompt with spaces'",
                                            "launch_claude false " + shlex.join(original))
                if failed_launch:
                    failed_ccr = tmp / "failed-ccr"
                    failed_ccr.write_text('#!/bin/bash\n'
                                          '[[ "${1:-}" == -v ]] && exit 0\n'
                                          'read -r children < /proc/$$/task/$$/children\n'
                                          'printf "%s" "$children" > "$FIXTURE/writer-pids"\n'
                                          'exit 9\n')
                    failed_ccr.chmod(0o755)
                    script = script.replace('"$ROOT/.nvm-isolated/npm-global/bin/ccr"',
                                            '"$FIXTURE/failed-ccr"')
                    script = script.replace("launch_claude false --print 'prompt with spaces'",
                                            "payload=$(python3 -c 'print(chr(120) * 60000)')\n"
                                            'launch_claude false "$payload" "$payload"')
                result = subprocess.run(["bash", "-c", script], env=env, capture_output=True, text=True, timeout=20)
                if failed_launch:
                    self.assertEqual(result.returncode, 9)
                    writers = (tmp / "writer-pids").read_text().split()
                    self.assertTrue(writers)
                    for _ in range(50):
                        active = []
                        for pid in writers:
                            try:
                                if Path(f"/proc/{pid}/stat").read_text().split()[2] != "Z":
                                    active.append(pid)
                            except FileNotFoundError:
                                pass
                        if not active:
                            break
                        time.sleep(0.02)
                    self.assertFalse(active, "pipe writer remained after CCR exited")
                    return
                self.assertEqual(result.returncode, 7, result.stderr)
                data = json.loads((tmp / "capture.json").read_text())
                self.assertEqual(data["home"], str(home))
                self.assertEqual(data["no_proxy"], expected)
                self.assertEqual(data["lowercase"], expected)
                self.assertEqual(data["config"], "fixture credential location\n")
                self.assertEqual(data["base_url"], f"http://127.0.0.1:{port}")
                self.assertTrue(data["transport_removed"])
                self.assertFalse(data["daemon_has_argv"])
                self.assertFalse(data["daemon_has_prompt"])
                self.assertEqual(data["args"][:-2], original)
            finally:
                if cold_start:
                    pidfile = store / ".claude-code-router/.claude-code-router.pid"
                    if pidfile.exists():
                        try:
                            os.kill(int(pidfile.read_text()), signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                server.terminate()
                server.wait()


if __name__ == "__main__":
    unittest.main()
