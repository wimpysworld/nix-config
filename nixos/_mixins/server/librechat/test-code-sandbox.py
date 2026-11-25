# The librechat-code-sandbox derivation runs these unit tests during its build.
import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

SCRIPT_PATH = Path(sys.argv[1])
sys.argv[1:] = []


def load_sandbox(state_dir: Path, **extra_env: str):
    env_updates = {
        "STATE_DIR": str(state_dir),
        "LIBRECHAT_CODE_API_KEY": "test-key",
        "SANDBOX_DISABLE_BWRAP": "1",
        "SANDBOX_WORKSPACE_TTL_DAYS": "7",
        "SANDBOX_STORAGE_TTL_DAYS": "30",
        **extra_env,
    }
    with mock.patch.dict(os.environ, env_updates, clear=False):
        spec = importlib.util.spec_from_file_location("code_sandbox_under_test", SCRIPT_PATH)
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module


class CodeSandboxTests(unittest.TestCase):
    def test_bwrap_shares_network_and_binds_resolve_conf(self):
        with tempfile.TemporaryDirectory() as tmp:
            mod = load_sandbox(Path(tmp), SANDBOX_DISABLE_BWRAP="0")
            with mock.patch.object(mod.shutil, "which", return_value="/usr/bin/bwrap"):
                cmd = mod.build_bwrap_cmd(["bash", "-c", "true"])
            self.assertIsNotNone(cmd)
            assert cmd is not None
            self.assertIn("--unshare-all", cmd)
            self.assertIn("--share-net", cmd)
            idx = cmd.index("/run/systemd/resolve")
            self.assertEqual(cmd[idx - 1], "--ro-bind-try")
            self.assertEqual(cmd[idx + 1], "/run/systemd/resolve")

    def test_bwrap_sets_tmp_cache_env_and_ignores_dot_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            mod = load_sandbox(Path(tmp), SANDBOX_DISABLE_BWRAP="0")
            captured_env: dict[str, str] = {}

            def fake_run(cmd, workspace_dir, env, timeout_sec, tracking_keys=()):
                captured_env.update(env)
                return mod.subprocess.CompletedProcess(cmd, 0, "", ""), False

            with (
                mock.patch.object(mod.shutil, "which", return_value="/usr/bin/bwrap"),
                mock.patch.object(mod, "_run_process_bounded", side_effect=fake_run),
            ):
                mod.run_sandboxed(["true"], Path(tmp), {"PATH": "/bin"}, 10.0)

            self.assertEqual(captured_env["UV_CACHE_DIR"], "/tmp/uv-cache")
            self.assertEqual(captured_env["PIP_CACHE_DIR"], "/tmp/pip-cache")
            self.assertEqual(captured_env["NPM_CONFIG_CACHE"], "/tmp/npm-cache")
            self.assertEqual(captured_env["MPLCONFIGDIR"], "/tmp/matplotlib")
            self.assertTrue(mod.should_ignore_workspace_path(".cache/uv/foo"))
            self.assertTrue(mod.should_ignore_workspace_path(".config/matplotlib/fontlist"))
            self.assertFalse(mod.should_ignore_workspace_path("report.pdf"))

    def test_per_user_workspace_scoping_and_cross_user_isolation(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            mock.patch.dict(os.environ, {"SANDBOX_DISABLE_BWRAP": "1"}),
        ):
            state = Path(tmp)
            mod = load_sandbox(state)

            res = mod.execute_code_request(
                {"lang": "py", "code": "open('/mnt/data/note.txt', 'w').write('hello')"},
                user_id="martin_123",
            )
            sid = str(res["session_id"])
            expected_ws = state / "users" / "martin_123" / "workspaces" / sid
            self.assertTrue((expected_ws / "note.txt").is_file(), res)
            self.assertEqual(mod.get_session_owner(sid), "martin_123")
            self.assertTrue(mod.check_session_access(sid, "martin_123"))
            self.assertFalse(mod.check_session_access(sid, "louise_456"))

            with self.assertRaises(PermissionError):
                mod.execute_code_request(
                    {"lang": "py", "code": "print('nope')", "session_id": sid},
                    user_id="louise_456",
                )

    def test_shared_skill_storage_accessible_across_users(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            mock.patch.dict(os.environ, {"SANDBOX_DISABLE_BWRAP": "1"}),
        ):
            state = Path(tmp)
            mod = load_sandbox(state)
            skill_sid = mod.to_nanoid("skill-seed")
            skill_fid = mod.to_nanoid(f"{skill_sid}:skills/demo/SKILL.md")
            mod.save_storage_object(
                skill_sid,
                skill_fid,
                "skills/demo/SKILL.md",
                b"# Demo skill\n",
                read_only=True,
                kind="skill",
                user_slug="martin_123",
            )
            res = mod.execute_code_request(
                {
                    "lang": "py",
                    "code": "print(open('/mnt/data/skills/demo/SKILL.md').read().strip())",
                    "files": [
                        {
                            "id": skill_fid,
                            "name": "skills/demo/SKILL.md",
                            "storage_session_id": skill_sid,
                            "kind": "skill",
                        }
                    ],
                },
                user_id="louise_456",
            )
            self.assertEqual(res["stdout"], "# Demo skill\n", res)

    def test_cleanup_expired_state_preserves_recent_and_readonly_skills(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            mod = load_sandbox(state)
            now = time.time()
            old_ws_ts = now - (10 * 86400)
            old_st_ts = now - (40 * 86400)

            old_sid = mod.to_nanoid("old-session")
            fresh_sid = mod.to_nanoid("fresh-session")
            skill_sid = mod.to_nanoid("skill-session")

            # Expired workspace + expired user storage for old_sid.
            mod.set_session_owner(old_sid, "martin_123")
            old_ws = mod.workspace_dir_for(old_sid, "martin_123")
            old_ws.mkdir(parents=True, exist_ok=True)
            old_file = old_ws / "scratch.txt"
            old_file.write_text("old", encoding="utf-8")
            os.utime(old_file, (old_ws_ts, old_ws_ts))
            os.utime(old_ws, (old_ws_ts, old_ws_ts))

            old_fid = mod.to_nanoid("old-file")
            mod.save_storage_object(
                old_sid, old_fid, "old.txt", b"old", read_only=False, kind="user", user_slug="martin_123"
            )
            old_st_dir = mod.storage_dir_for(old_sid, "martin_123")
            for item in old_st_dir.iterdir():
                os.utime(item, (old_st_ts, old_st_ts))

            # Fresh workspace + storage for fresh_sid.
            mod.set_session_owner(fresh_sid, "martin_123")
            fresh_ws = mod.workspace_dir_for(fresh_sid, "martin_123")
            fresh_ws.mkdir(parents=True, exist_ok=True)
            (fresh_ws / "new.txt").write_text("new", encoding="utf-8")

            # Old read-only skill storage must survive cleanup.
            skill_fid = mod.to_nanoid("skill-file")
            mod.save_storage_object(
                skill_sid, skill_fid, "skills/a/SKILL.md", b"skill", read_only=True, kind="skill"
            )
            skill_st_dir = mod.storage_dir_for(skill_sid, shared=True)
            for item in skill_st_dir.iterdir():
                os.utime(item, (old_st_ts, old_st_ts))

            summary = mod.cleanup_expired_state(now_ts=now)
            self.assertEqual(summary["removed_workspaces"], 1)
            self.assertEqual(summary["removed_storage_objects"], 1)
            self.assertEqual(summary["removed_storage_sessions"], 1)
            self.assertFalse(old_ws.exists())
            self.assertFalse(old_st_dir.exists())
            self.assertFalse((state / "sessions" / f"{old_sid}.json").exists())
            self.assertTrue(fresh_ws.exists())
            self.assertTrue((skill_st_dir / skill_fid).is_file())


if __name__ == "__main__":
    unittest.main()
