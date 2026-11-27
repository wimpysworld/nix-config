# The librechat-code-sandbox derivation runs these unit and live HTTP tests during its build.
import base64
import contextlib
import http.client
import importlib.util
import json
import os
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

SCRIPT_PATH = Path(sys.argv[1])
sys.argv[1:] = []


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def make_ed25519_keypair(
    directory: Path, name: str = "public.pem"
) -> tuple[Ed25519PrivateKey, str, str, Path]:
    private_key = Ed25519PrivateKey.generate()
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("ascii")
    private_pem_b64 = base64.b64encode(private_pem.encode("utf-8")).decode("ascii")
    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    public_path = directory / name
    public_path.write_bytes(public_pem)
    return private_key, private_pem, private_pem_b64, public_path


def mint_jwt(
    private_key: Ed25519PrivateKey,
    *,
    sub: object = "martin_123",
    iss: object = "librechat",
    aud: object = "codeapi",
    alg: str = "EdDSA",
    exp_offset: int = 300,
    nbf_offset: int | None = 0,
    extra_claims: dict[str, object] | None = None,
    omit_claims: tuple[str, ...] = (),
) -> str:
    now = int(time.time())
    header = {"alg": alg, "typ": "JWT", "kid": "lc-codeapi-2026-05"}
    claims: dict[str, object] = {
        "iss": iss,
        "aud": aud,
        "sub": sub,
        "iat": now,
        "exp": now + exp_offset,
        "jti": f"test-{now}",
        "tenant_id": "legacy",
        "role": "USER",
        "principal_source": "librechat_jwt",
    }
    if nbf_offset is not None:
        claims["nbf"] = now + nbf_offset
    if extra_claims:
        claims.update(extra_claims)
    for key in omit_claims:
        claims.pop(key, None)

    header_b64 = _b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url(json.dumps(claims, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    signature = private_key.sign(signing_input)
    return f"{header_b64}.{payload_b64}.{_b64url(signature)}"


def http_request(
    port: int,
    method: str,
    path: str,
    *,
    body: bytes | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[int, dict[str, str], bytes]:
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=15)
    try:
        conn.request(method, path, body=body, headers=headers or {})
        resp = conn.getresponse()
        data = resp.read()
        resp_headers = {k.lower(): v for k, v in resp.getheaders()}
        return resp.status, resp_headers, data
    finally:
        conn.close()


def build_multipart(
    fields: dict[str, str], files: list[tuple[str, bytes]]
) -> tuple[str, bytes]:
    boundary = "----LibreChatSandboxTestBoundary"
    parts: list[bytes] = []
    for name, value in fields.items():
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n".encode("utf-8")
        )
    for filename, content in files:
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            f"Content-Type: application/octet-stream\r\n\r\n".encode("utf-8")
            + content
            + b"\r\n"
        )
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    return f"multipart/form-data; boundary={boundary}", b"".join(parts)


def load_sandbox(state_dir: Path, **extra_env: str):
    env_updates = {
        "STATE_DIR": str(state_dir),
        "LIBRECHAT_CODE_API_KEY": "test-key",
        "CODEAPI_JWT_PUBLIC_KEY": "",
        "CODEAPI_JWT_PUBLIC_KEY_FILE": "",
        "CODEAPI_JWT_ISSUER": "librechat",
        "CODEAPI_JWT_AUDIENCE": "codeapi",
        "BWRAP_BIN": "",
        "PASTA_BIN": "",
        "SANDBOX_CHROME_BIN": "",
        "SANDBOX_STORE_PATHS_FILE": "",
        "SANDBOX_DISABLE_BWRAP": "1",
        "SANDBOX_DISABLE_PASTA": "0",
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


@contextlib.contextmanager
def running_sandbox_server(state_dir: Path, **extra_env: str):
    with mock.patch.dict(os.environ, {"SANDBOX_DISABLE_BWRAP": "1"}, clear=False):
        mod = load_sandbox(state_dir, **extra_env)
        server = mod.ThreadingHTTPServer(("127.0.0.1", 0), mod.SandboxHandler)
        port = server.server_address[1]
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            yield mod, port
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


class CodeSandboxTests(unittest.TestCase):
    def test_bwrap_uses_minimal_etc_runtime_identity_and_4gib_tmpfs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fake_etc = root / "sandbox-etc"
            (fake_etc / "fonts").mkdir(parents=True)
            (fake_etc / "passwd").write_text("", encoding="utf-8")
            (fake_etc / "group").write_text("", encoding="utf-8")
            state_dir = root / "state"
            mod = load_sandbox(
                state_dir,
                SANDBOX_DISABLE_BWRAP="0",
                SANDBOX_ETC_DIR=str(fake_etc),
            )
            with (
                mock.patch.dict(
                    os.environ,
                    {"SANDBOX_DISABLE_BWRAP": "0", "SANDBOX_ETC_DIR": str(fake_etc)},
                    clear=False,
                ),
                mock.patch.object(mod.shutil, "which", return_value="/usr/bin/bwrap"),
            ):
                cmd = mod.build_bwrap_cmd(["bash", "-c", "true"])
            self.assertIsNotNone(cmd)
            assert cmd is not None
            self.assertIn("--unshare-all", cmd)
            self.assertIn("--unshare-user", cmd)
            self.assertIn("--share-net", cmd)
            self.assertIn("--disable-userns", cmd)
            hostname_idx = cmd.index("--hostname")
            self.assertEqual(cmd[hostname_idx + 1], "sandbox")

            # When pasta is active (share_net=False), --share-net must be omitted.
            with (
                mock.patch.dict(
                    os.environ,
                    {
                        "SANDBOX_DISABLE_BWRAP": "0",
                        "SANDBOX_DISABLE_PASTA": "0",
                        "PASTA_BIN": "/nix/store/yyy-passt/bin/pasta",
                        "SANDBOX_ETC_DIR": str(fake_etc),
                    },
                    clear=False,
                ),
                mock.patch.object(mod.shutil, "which", return_value="/usr/bin/bwrap"),
            ):
                pasta_bwrap_cmd = mod.build_bwrap_cmd(["bash", "-c", "true"])
            self.assertIsNotNone(pasta_bwrap_cmd)
            assert pasta_bwrap_cmd is not None
            self.assertIn("--unshare-all", pasta_bwrap_cmd)
            self.assertIn("--unshare-user", pasta_bwrap_cmd)
            self.assertIn("--disable-userns", pasta_bwrap_cmd)
            self.assertNotIn("--share-net", pasta_bwrap_cmd)

            # Must mount SANDBOX_ETC_DIR, never host /etc or /run/systemd/resolve.
            self.assertNotIn("/run/systemd/resolve", cmd)
            etc_idx = cmd.index(str(fake_etc))
            self.assertEqual(cmd[etc_idx - 1], "--ro-bind")
            self.assertEqual(cmd[etc_idx + 1], "/etc")
            for idx, arg in enumerate(cmd):
                if arg in ("--ro-bind", "--ro-bind-try", "--bind"):
                    self.assertNotEqual(
                        cmd[idx + 1],
                        "/etc",
                        "host /etc must never be mounted directly",
                    )

            # Runtime passwd and group must contain only root and current uid/gid.
            passwd_dst_idx = cmd.index("/etc/passwd")
            self.assertEqual(cmd[passwd_dst_idx - 2], "--ro-bind")
            passwd_file = Path(cmd[passwd_dst_idx - 1])
            self.assertEqual(passwd_file, state_dir / "etc" / "passwd")
            passwd_lines = passwd_file.read_text(encoding="utf-8").splitlines()
            expected_uids = {0, os.getuid()}
            self.assertEqual(len(passwd_lines), len(expected_uids))
            self.assertTrue(passwd_lines[0].startswith("root:x:0:0:"))
            if os.getuid() != 0:
                fields = passwd_lines[1].split(":")
                self.assertEqual(int(fields[2]), os.getuid())
                self.assertEqual(int(fields[3]), os.getgid())
                self.assertEqual(fields[5], "/mnt/data")
                self.assertEqual(fields[6], "/bin/sh")

            group_dst_idx = cmd.index("/etc/group")
            self.assertEqual(cmd[group_dst_idx - 2], "--ro-bind")
            group_file = Path(cmd[group_dst_idx - 1])
            self.assertEqual(group_file, state_dir / "etc" / "group")
            group_lines = group_file.read_text(encoding="utf-8").splitlines()
            expected_gids = {0, os.getgid()}
            self.assertEqual(len(group_lines), len(expected_gids))
            self.assertEqual(group_lines[0], "root:x:0:")
            if os.getgid() != 0:
                gfields = group_lines[1].split(":")
                self.assertEqual(int(gfields[2]), os.getgid())

            # /run/current-system must never be mounted.
            self.assertNotIn("/run/current-system", cmd)

            # /dev/shm tmpfs must be capped at 512 MiB and mounted after /dev.
            dev_idx = cmd.index("--dev")
            shm_dst_idx = cmd.index("/dev/shm")
            self.assertGreater(shm_dst_idx, dev_idx)
            self.assertEqual(cmd[shm_dst_idx - 1], "--tmpfs")
            self.assertEqual(cmd[shm_dst_idx - 3], "--size")
            self.assertEqual(cmd[shm_dst_idx - 2], "536870912")

            # /tmp tmpfs must be capped at 4 GiB via --size 4294967296.
            tmp_dst_idx = cmd.index("/tmp")
            self.assertEqual(cmd[tmp_dst_idx - 1], "--tmpfs")
            self.assertEqual(cmd[tmp_dst_idx - 3], "--size")
            self.assertEqual(cmd[tmp_dst_idx - 2], "4294967296")

            # --remount-ro / must follow /tmp, /dev/shm, and /mnt/data.
            remount_idx = cmd.index("--remount-ro")
            self.assertEqual(cmd[remount_idx + 1], "/")
            self.assertGreater(remount_idx, tmp_dst_idx)
            self.assertGreater(remount_idx, shm_dst_idx)
            self.assertGreater(remount_idx, cmd.index("/mnt/data"))

    def test_bwrap_memfd_args_and_pasta_attach_lifecycle_and_error_handling(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            state_dir = root / "state"
            fake_etc = root / "sandbox-etc"
            (fake_etc / "fonts").mkdir(parents=True)
            store_paths_file = root / "store-paths"
            store_paths_file.write_text(
                "/nix/store/aaa-bash\n/nix/store/bbb-python\n/nix/store/aaa-bash\n\n",
                encoding="utf-8",
            )
            cache_dir = root / "cache"
            cache_dir.mkdir()
            record_file = root / "recorded.json"
            pasta_record_file = root / "pasta-recorded.json"
            pasta_bg_pid_record = root / "pasta-bg.pid"

            fake_bwrap = root / "fake-bwrap"
            fake_bwrap.write_text(
                f"#!{sys.executable}\n"
                "import json, os, sys, time\n"
                "argv = sys.argv[1:]\n"
                "args_fd = info_fd = block_fd = None\n"
                "cmd = []\n"
                "i = 0\n"
                "while i < len(argv):\n"
                "    if argv[i] == '--args':\n"
                "        args_fd = int(argv[i + 1]); i += 2\n"
                "    elif argv[i] == '--info-fd':\n"
                "        info_fd = int(argv[i + 1]); i += 2\n"
                "    elif argv[i] == '--block-fd':\n"
                "        block_fd = int(argv[i + 1]); i += 2\n"
                "    elif argv[i] == '--':\n"
                "        cmd = argv[i + 1:]; break\n"
                "    else:\n"
                "        i += 1\n"
                "raw_args = b''\n"
                "if args_fd is not None:\n"
                "    while True:\n"
                "        chunk = os.read(args_fd, 65536)\n"
                "        if not chunk:\n"
                "            break\n"
                "        raw_args += chunk\n"
                "    os.close(args_fd)\n"
                f"open({str(record_file)!r}, 'w').write(json.dumps({{'argv': argv, 'args': raw_args[:-1].decode('utf-8').split('\\0') if raw_args.endswith(b'\\0') else [], 'cmd': cmd}}))\n"
                "if cmd == ['early-fail']:\n"
                "    sys.stderr.write('bwrap: early startup failure\\n')\n"
                "    sys.exit(42)\n"
                "if info_fd is not None:\n"
                "    os.write(info_fd, json.dumps({'child-pid': os.getpid()}).encode('utf-8') + b'\\n')\n"
                "    os.close(info_fd)\n"
                "if block_fd is not None:\n"
                "    data = os.read(block_fd, 16)\n"
                "    os.close(block_fd)\n"
                "    if data != b'1':\n"
                "        sys.stderr.write('unexpected block-fd close\\n')\n"
                "        sys.exit(99)\n"
                "if cmd == ['sleep-forever']:\n"
                "    time.sleep(30)\n"
                "print('ran:' + ' '.join(cmd))\n",
                encoding="utf-8",
            )
            fake_bwrap.chmod(0o755)

            fake_pasta = root / "fake-pasta"
            fake_pasta.write_text(
                f"#!{sys.executable}\n"
                "import json, os, subprocess, sys\n"
                "argv = sys.argv[1:]\n"
                f"open({str(pasta_record_file)!r}, 'w').write(json.dumps({{'argv': argv}}))\n"
                "pid_file = None\n"
                "for idx, tok in enumerate(argv):\n"
                "    if tok == '-P' and idx + 1 < len(argv):\n"
                "        pid_file = argv[idx + 1]\n"
                "if os.environ.get('FAKE_PASTA_FAIL') == '1':\n"
                "    sys.stderr.write('pasta: simulated attach failure\\n')\n"
                "    sys.exit(7)\n"
                "bg = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)\n"
                "if pid_file:\n"
                "    open(pid_file, 'w').write(f'{bg.pid}\\n')\n"
                f"open({str(pasta_bg_pid_record)!r}, 'w').write(str(bg.pid))\n",
                encoding="utf-8",
            )
            fake_pasta.chmod(0o755)

            mod = load_sandbox(state_dir, SANDBOX_DISABLE_BWRAP="0")
            env_cfg = {
                "SANDBOX_DISABLE_BWRAP": "0",
                "SANDBOX_DISABLE_PASTA": "0",
                "BWRAP_BIN": str(fake_bwrap),
                "PASTA_BIN": str(fake_pasta),
                "SANDBOX_ETC_DIR": str(fake_etc),
                "SANDBOX_STORE_PATHS_FILE": str(store_paths_file),
            }

            # 1. Normal execution with pasta enabled: bwrap outer (--args memfd, --info-fd,
            # --block-fd, --disable-userns, NO --share-net) + pasta attached via -P <pidfile> <child_pid>.
            with mock.patch.dict(os.environ, env_cfg, clear=False):
                self.assertEqual(mod.resolve_bwrap_bin(), str(fake_bwrap))
                res, overflow = mod.run_sandboxed(
                    ["python3", "-c", "print(1)"],
                    root,
                    {"PATH": os.environ.get("PATH", "")},
                    10.0,
                    cache_dir=cache_dir,
                )
            self.assertFalse(overflow)
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertEqual(res.stdout, "ran:python3 -c print(1)\n")

            recorded = json.loads(record_file.read_text(encoding="utf-8"))
            self.assertIn("--args", recorded["argv"])
            self.assertIn("--info-fd", recorded["argv"])
            self.assertIn("--block-fd", recorded["argv"])
            bwrap_args = recorded["args"]
            self.assertIn("--unshare-all", bwrap_args)
            self.assertIn("--disable-userns", bwrap_args)
            self.assertNotIn("--share-net", bwrap_args)
            self.assertNotIn("/nix/store", bwrap_args)
            self.assertNotIn("/run/current-system", bwrap_args)
            self.assertNotIn("--", bwrap_args)
            self.assertEqual(bwrap_args[-2:], ["--remount-ro", "/"])
            self.assertIn("/nix/store/aaa-bash", bwrap_args)
            self.assertIn("/nix/store/bbb-python", bwrap_args)
            self.assertEqual(bwrap_args.count("/nix/store/aaa-bash"), 2)
            remount_idx = bwrap_args.index("--remount-ro")
            self.assertGreater(remount_idx, bwrap_args.index("/var/cache/sandbox"))
            self.assertGreater(remount_idx, bwrap_args.index("/mnt/data"))
            self.assertGreater(remount_idx, bwrap_args.index("/dev/shm"))
            self.assertGreater(remount_idx, bwrap_args.index("/tmp"))

            pasta_rec = json.loads(pasta_record_file.read_text(encoding="utf-8"))
            pasta_argv = pasta_rec["argv"]
            self.assertEqual(
                pasta_argv[: len(mod.PASTA_ISOLATION_FLAGS)],
                list(mod.PASTA_ISOLATION_FLAGS),
            )
            self.assertIn("-4", pasta_argv)
            for flag, expected in (
                ("-I", "eth0"),
                ("-a", "192.0.2.2"),
                ("-n", "24"),
                ("-g", "192.0.2.1"),
            ):
                flag_idx = pasta_argv.index(flag)
                self.assertEqual(pasta_argv[flag_idx + 1], expected)
            self.assertEqual(pasta_argv[len(mod.PASTA_ISOLATION_FLAGS)], "-P")
            pasta_pid_path = Path(pasta_argv[len(mod.PASTA_ISOLATION_FLAGS) + 1])
            self.assertFalse(pasta_pid_path.exists(), "pasta PID file must be unlinked")
            self.assertTrue(pasta_argv[-1].isdigit())
            bg_pid = int(pasta_bg_pid_record.read_text(encoding="utf-8").strip())
            self.assertFalse(
                mod._pid_is_alive(bg_pid),
                "pasta daemon must be cleaned up when bwrap finishes",
            )
            self.assertFalse(
                list((state_dir / "tmp").glob("bwrap-args-*")),
                "bwrap --args must use anonymous memfd, never on-disk files",
            )

            # 2. bwrap early-exit before writing child-pid returns bwrap's stderr without hanging.
            with mock.patch.dict(os.environ, env_cfg, clear=False):
                early_res, _ = mod.run_sandboxed(
                    ["early-fail"],
                    root,
                    {"PATH": os.environ.get("PATH", "")},
                    10.0,
                )
            self.assertEqual(early_res.returncode, 42)
            self.assertIn("early startup failure", early_res.stderr)

            # 3. pasta attach failure kills bwrap, surfaces pasta stderr, and leaves no PID file.
            with mock.patch.dict(
                os.environ, {**env_cfg, "FAKE_PASTA_FAIL": "1"}, clear=False
            ):
                # Force pasta subprocess to see FAKE_PASTA_FAIL via a wrapper env patch.
                real_sub_run = mod.subprocess.run

                def run_with_fail_env(cmd_arg, *args, **kwargs):
                    kwargs["env"] = {**(kwargs.get("env") or {}), "FAKE_PASTA_FAIL": "1"}
                    return real_sub_run(cmd_arg, *args, **kwargs)

                with mock.patch.object(mod.subprocess, "run", side_effect=run_with_fail_env):
                    pasta_fail_res, _ = mod.run_sandboxed(
                        ["sleep-forever"],
                        root,
                        {"PATH": os.environ.get("PATH", "")},
                        10.0,
                    )
            self.assertEqual(pasta_fail_res.returncode, 7)
            self.assertIn("pasta failed (exit 7)", pasta_fail_res.stderr)
            self.assertIn("simulated attach failure", pasta_fail_res.stderr)
            self.assertFalse(list((state_dir / "tmp").glob("pasta-*.pid")))

            # 4. Timeout terminates both bwrap and the attached pasta daemon.
            with (
                mock.patch.dict(os.environ, env_cfg, clear=False),
                self.assertRaises(mod.subprocess.TimeoutExpired),
            ):
                mod.run_sandboxed(
                    ["sleep-forever"],
                    root,
                    {"PATH": os.environ.get("PATH", "")},
                    0.5,
                )
            timeout_bg_pid = int(pasta_bg_pid_record.read_text(encoding="utf-8").strip())
            self.assertFalse(
                mod._pid_is_alive(timeout_bg_pid),
                "pasta daemon must be terminated on command timeout",
            )
            self.assertFalse(list((state_dir / "tmp").glob("pasta-*.pid")))

            # 5. SANDBOX_DISABLE_PASTA=1 skips pasta, keeps --share-net + --disable-userns + --args memfd.
            with mock.patch.dict(
                os.environ, {**env_cfg, "SANDBOX_DISABLE_PASTA": "1"}, clear=False
            ):
                no_pasta_res, _ = mod.run_sandboxed(
                    ["echo", "direct"],
                    root,
                    {"PATH": os.environ.get("PATH", "")},
                    10.0,
                )
            self.assertEqual(no_pasta_res.returncode, 0, no_pasta_res.stderr)
            self.assertEqual(no_pasta_res.stdout, "ran:echo direct\n")
            recorded_no_pasta = json.loads(record_file.read_text(encoding="utf-8"))
            self.assertIn("--args", recorded_no_pasta["argv"])
            self.assertNotIn("--info-fd", recorded_no_pasta["argv"])
            self.assertNotIn("--block-fd", recorded_no_pasta["argv"])
            self.assertIn("--unshare-all", recorded_no_pasta["args"])
            self.assertIn("--share-net", recorded_no_pasta["args"])
            self.assertIn("--disable-userns", recorded_no_pasta["args"])

    def test_bwrap_sets_tmp_cache_env_and_ignores_dot_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            admin_gitconfig = root / "admin-gitconfig"
            admin_gitconfig.write_text("[user]\n  name = Martin Wimpress\n", encoding="utf-8")
            mod = load_sandbox(root / "state", SANDBOX_DISABLE_BWRAP="0")
            captured_env: dict[str, str] = {}

            def fake_run(cmd, workspace_dir, env, timeout_sec, tracking_keys=()):
                captured_env.update(env)
                return mod.subprocess.CompletedProcess(cmd, 0, "", ""), False

            dirty_env = {
                "PATH": "/bin",
                "SSL_CERT_FILE": "/etc/ssl/certs/ca-bundle.crt",
                "REQUESTS_CA_BUNDLE": "/etc/ssl/certs/ca-bundle.crt",
                "FONTCONFIG_FILE": "/etc/fonts/fonts.conf",
                "PORT": "3082",
                "HOST": "127.0.0.1",
                "STATE_DIRECTORY": "/var/lib/librechat-code-sandbox",
                "SYSTEMD_EXEC_PID": "9999",
                "INVOCATION_ID": "abc123",
                "SANDBOX_ETC_DIR": "/nix/store/fake-sandbox-etc",
                "SANDBOX_ADMIN_GIT_CONFIG": str(admin_gitconfig),
                "SANDBOX_CHROME_BIN": "/nix/store/fake-chromium/bin/chromium",
                "SANDBOX_STORE_PATHS_FILE": "/nix/store/fake-closure/store-paths",
                "BWRAP_BIN": "/nix/store/fake-bwrap/bin/bwrap",
                "PASTA_BIN": "/nix/store/fake-passt/bin/pasta",
                "SANDBOX_STORAGE_TTL_DAYS": "30",
                "CODEAPI_JWT_PUBLIC_KEY_FILE": "/var/lib/librechat-codeapi-keys/public.pem",
                "LIBRECHAT_CODE_API_KEY": "top-secret-key",
                "STATE_DIR": "/var/lib/librechat-code-sandbox",
                "UNEXPECTED_SECRET": "do-not-leak",
            }
            with (
                mock.patch.object(mod.shutil, "which", return_value="/usr/bin/bwrap"),
                mock.patch.object(mod, "_run_process_bounded", side_effect=fake_run),
            ):
                mod.run_sandboxed(["true"], root, dirty_env, 10.0)

            self.assertEqual(captured_env["HOME"], "/mnt/data")
            self.assertEqual(captured_env["LIBRECHAT_CODE_DATA_DIR"], "/mnt/data")
            self.assertEqual(captured_env["TMPDIR"], "/tmp")
            self.assertEqual(captured_env["TERM"], "dumb")
            self.assertEqual(captured_env["GOMAXPROCS"], "4")
            self.assertEqual(captured_env["GOTELEMETRY"], "off")
            self.assertEqual(captured_env["CHROME_NO_SANDBOX"], "1")
            self.assertEqual(
                captured_env["AGENT_BROWSER_ARGS"],
                "--no-sandbox,--disable-dev-shm-usage,--disable-gpu",
            )
            self.assertEqual(
                captured_env["CHROME_PATH"], "/nix/store/fake-chromium/bin/chromium"
            )
            self.assertEqual(
                captured_env["PUPPETEER_EXECUTABLE_PATH"],
                "/nix/store/fake-chromium/bin/chromium",
            )
            self.assertEqual(
                captured_env["PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"],
                "/nix/store/fake-chromium/bin/chromium",
            )
            self.assertEqual(captured_env["XDG_CONFIG_HOME"], "/tmp/xdg-config")
            self.assertEqual(captured_env["XDG_DATA_HOME"], "/tmp/xdg-data")
            self.assertEqual(captured_env["XDG_STATE_HOME"], "/tmp/xdg-state")
            self.assertEqual(captured_env["NIX_STATE_DIR"], "/tmp/nix-state")
            self.assertEqual(captured_env["UV_CACHE_DIR"], "/tmp/uv-cache")
            self.assertEqual(captured_env["PIP_CACHE_DIR"], "/tmp/pip-cache")
            self.assertEqual(captured_env["NPM_CONFIG_CACHE"], "/tmp/npm-cache")
            self.assertEqual(captured_env["MPLCONFIGDIR"], "/tmp/matplotlib")
            self.assertEqual(captured_env["GOCACHE"], "/tmp/go-cache")
            self.assertEqual(captured_env["GOMODCACHE"], "/tmp/go-mod")
            self.assertEqual(captured_env["GOPATH"], "/tmp/go")
            self.assertEqual(captured_env["GOTMPDIR"], "/tmp")
            self.assertEqual(captured_env["PATH"], "/bin")
            self.assertEqual(captured_env["SSL_CERT_FILE"], "/etc/ssl/certs/ca-bundle.crt")
            self.assertEqual(captured_env["REQUESTS_CA_BUNDLE"], "/etc/ssl/certs/ca-bundle.crt")
            self.assertEqual(captured_env["FONTCONFIG_FILE"], "/etc/fonts/fonts.conf")
            self.assertNotIn("GIT_CONFIG_SYSTEM", captured_env)
            for stripped in (
                "PORT",
                "HOST",
                "STATE_DIRECTORY",
                "SYSTEMD_EXEC_PID",
                "INVOCATION_ID",
                "BWRAP_BIN",
                "PASTA_BIN",
                "SANDBOX_CHROME_BIN",
                "SANDBOX_ETC_DIR",
                "SANDBOX_ADMIN_GIT_CONFIG",
                "SANDBOX_STORE_PATHS_FILE",
                "SANDBOX_STORAGE_TTL_DAYS",
                "CODEAPI_JWT_PUBLIC_KEY_FILE",
                "LIBRECHAT_CODE_API_KEY",
                "STATE_DIR",
                "UNEXPECTED_SECRET",
            ):
                self.assertNotIn(stripped, captured_env)

            # ADMIN role receives GIT_CONFIG_SYSTEM while still stripping SANDBOX_* vars.
            admin_env = mod.build_sandbox_env(
                dirty_env,
                root,
                use_bwrap=True,
                caller_role="ADMIN",
                cache_mounted=True,
            )
            self.assertEqual(admin_env["GIT_CONFIG_SYSTEM"], str(admin_gitconfig))
            self.assertEqual(admin_env["XDG_CONFIG_HOME"], "/var/cache/sandbox/xdg-config")
            self.assertEqual(admin_env["XDG_DATA_HOME"], "/var/cache/sandbox/xdg-data")
            self.assertEqual(admin_env["XDG_STATE_HOME"], "/var/cache/sandbox/xdg-state")
            self.assertEqual(admin_env["NIX_STATE_DIR"], "/var/cache/sandbox/nix-state")
            self.assertNotIn("SANDBOX_ETC_DIR", admin_env)
            self.assertNotIn("SANDBOX_ADMIN_GIT_CONFIG", admin_env)

            # USER role must never receive GIT_CONFIG_SYSTEM.
            user_env = mod.build_sandbox_env(
                dirty_env,
                root,
                use_bwrap=True,
                caller_role="USER",
                cache_mounted=True,
            )
            self.assertNotIn("GIT_CONFIG_SYSTEM", user_env)
            self.assertNotIn("SANDBOX_ETC_DIR", user_env)
            self.assertNotIn("SANDBOX_ADMIN_GIT_CONFIG", user_env)

            self.assertTrue(mod.should_ignore_workspace_path(".cache/uv/foo"))
            self.assertTrue(mod.should_ignore_workspace_path(".config/matplotlib/fontlist"))
            self.assertFalse(mod.should_ignore_workspace_path("report.pdf"))

    def test_allowlist_strips_host_env_vars_in_execute_code_request(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            dirty_host_env = {
                "SANDBOX_DISABLE_BWRAP": "1",
                "SSL_CERT_FILE": "/etc/ssl/certs/test-ca.pem",
                "REQUESTS_CA_BUNDLE": "/etc/ssl/certs/test-ca.pem",
                "PORT": "3082",
                "HOST": "127.0.0.1",
                "STATE_DIRECTORY": "/var/lib/librechat-code-sandbox",
                "SYSTEMD_EXEC_PID": "4242",
                "INVOCATION_ID": "inv-1234",
                "SANDBOX_STORAGE_TTL_DAYS": "30",
                "CODEAPI_JWT_PUBLIC_KEY_FILE": "/var/lib/librechat-codeapi-keys/public.pem",
                "LIBRECHAT_CODE_API_KEY": "secret-api-key",
                "STATE_DIR": str(state),
                "UNEXPECTED_SECRET": "must-not-appear",
            }
            with mock.patch.dict(os.environ, dirty_host_env, clear=False):
                mod = load_sandbox(state)
                res = mod.execute_code_request(
                    {
                        "lang": "py",
                        "code": "import json, os; print(json.dumps(dict(os.environ)))",
                    },
                    user_id="martin_123",
                )
            child_env = json.loads(str(res["stdout"]))
            for stripped in (
                "PORT",
                "HOST",
                "STATE_DIRECTORY",
                "SYSTEMD_EXEC_PID",
                "INVOCATION_ID",
                "SANDBOX_STORAGE_TTL_DAYS",
                "CODEAPI_JWT_PUBLIC_KEY_FILE",
                "LIBRECHAT_CODE_API_KEY",
                "STATE_DIR",
                "UNEXPECTED_SECRET",
            ):
                self.assertNotIn(stripped, child_env)
            self.assertEqual(child_env["TERM"], "dumb")
            self.assertEqual(child_env["GOMAXPROCS"], "4")
            self.assertEqual(child_env["SSL_CERT_FILE"], "/etc/ssl/certs/test-ca.pem")
            self.assertEqual(child_env["REQUESTS_CA_BUNDLE"], "/etc/ssl/certs/test-ca.pem")
            self.assertIn("PATH", child_env)
            self.assertEqual(
                child_env["HOME"],
                str(mod.workspace_dir_for(str(res["session_id"]), "martin_123")),
            )

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

    def test_stateless_file_entry_session_id_fallback(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            mock.patch.dict(os.environ, {"SANDBOX_DISABLE_BWRAP": "1"}),
        ):
            state = Path(tmp)
            mod = load_sandbox(state)
            upload_sid = mod.to_nanoid("stateless-upload-session")
            file_id = mod.to_nanoid(f"{upload_sid}:notes.txt")
            mod.save_storage_object(
                upload_sid, file_id, "notes.txt", b"via-session-id\n", user_slug="martin_123"
            )
            res = mod.execute_code_request(
                {
                    "lang": "py",
                    "code": "print(open('/mnt/data/notes.txt').read().strip())",
                    "files": [
                        {
                            "id": file_id,
                            "name": "notes.txt",
                            "session_id": upload_sid,
                        }
                    ],
                },
                user_id="martin_123",
            )
            self.assertEqual(res["stdout"], "via-session-id\n", res)

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

    def test_ignored_repo_and_build_dirs_pruned_and_never_emitted(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            mock.patch.dict(os.environ, {"SANDBOX_DISABLE_BWRAP": "1"}),
        ):
            state = Path(tmp)
            mod = load_sandbox(state)

            for ignored in (
                ".git/HEAD",
                ".git/objects/ab/cdef",
                "__pycache__/mod.cpython-312.pyc",
                "sub/node_modules/pkg/index.js",
                "crate/target/debug/app",
                ".pytest_cache/v/cache/lastfailed",
                ".ruff_cache/0.5/entry",
                ".mypy_cache/3.12/a.json",
                ".venv/bin/python",
            ):
                self.assertTrue(mod.should_ignore_workspace_path(ignored), ignored)
            self.assertFalse(mod.should_ignore_workspace_path("src/main.rs"))

            code = (
                "from pathlib import Path\n"
                "for rel in [\n"
                "  '.git/HEAD',\n"
                "  '.git/objects/00/abc',\n"
                "  '__pycache__/foo.pyc',\n"
                "  'node_modules/pkg/index.js',\n"
                "  'target/debug/bin',\n"
                "  'report.txt',\n"
                "]:\n"
                "  p = Path('/mnt/data') / rel\n"
                "  p.parent.mkdir(parents=True, exist_ok=True)\n"
                "  p.write_text('data', encoding='utf-8')\n"
            )
            res = mod.execute_code_request({"lang": "py", "code": code}, user_id="martin_123")
            emitted = [item["name"] for item in res["files"]]
            self.assertEqual(emitted, ["report.txt"], res)

            # Confirm os.walk prunes ignored directories without descending.
            ws = mod.workspace_dir_for(str(res["session_id"]), "martin_123")
            visited_roots: list[str] = []
            real_walk = mod.os.walk

            def spy_walk(top, *args, **kwargs):
                for root, dirs, files in real_walk(top, *args, **kwargs):
                    visited_roots.append(Path(root).name)
                    yield root, dirs, files

            with mock.patch.object(mod.os, "walk", side_effect=spy_walk):
                snap = mod.snapshot_workspace(ws)
            self.assertEqual(list(snap.keys()), ["report.txt"])
            for pruned in (".git", "__pycache__", "node_modules", "target"):
                self.assertNotIn(pruned, visited_roots)

    def test_deletion_tombstones_block_stale_reinjection_and_allow_updates(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            mock.patch.dict(os.environ, {"SANDBOX_DISABLE_BWRAP": "1"}),
        ):
            state = Path(tmp)
            mod = load_sandbox(state)

            upload_sid = mod.to_nanoid("upload-v1")
            file_v1_id = mod.to_nanoid(f"{upload_sid}:draft.txt")
            mod.save_storage_object(
                upload_sid, file_v1_id, "draft.txt", b"version-1", user_slug="martin_123"
            )
            stale_ref = {
                "id": file_v1_id,
                "name": "draft.txt",
                "storage_session_id": upload_sid,
            }

            # Turn 1: inject v1 and delete it inside the sandbox.
            res1 = mod.execute_code_request(
                {
                    "lang": "py",
                    "code": "import os; os.remove('/mnt/data/draft.txt')",
                    "files": [stale_ref],
                },
                user_id="martin_123",
            )
            sid = str(res1["session_id"])
            self.assertEqual(res1["deleted_files"], ["draft.txt"], res1)
            tombstone_file = state / "sessions" / f"{sid}.tombstones.json"
            self.assertTrue(tombstone_file.is_file())

            # Turn 2: stale ref with identical blob must NOT be re-injected.
            res2 = mod.execute_code_request(
                {
                    "lang": "py",
                    "session_id": sid,
                    "code": "import os; print(os.path.exists('/mnt/data/draft.txt'))",
                    "files": [stale_ref],
                },
                user_id="martin_123",
            )
            self.assertEqual(res2["stdout"], "False\n", res2)

            # Turn 3: new upload with updated content clears tombstone and writes new file.
            upload_sid_v2 = mod.to_nanoid("upload-v2")
            file_v2_id = mod.to_nanoid(f"{upload_sid_v2}:draft.txt")
            mod.save_storage_object(
                upload_sid_v2, file_v2_id, "draft.txt", b"version-2", user_slug="martin_123"
            )
            res3 = mod.execute_code_request(
                {
                    "lang": "py",
                    "session_id": sid,
                    "code": "print(open('/mnt/data/draft.txt').read())",
                    "files": [
                        {
                            "id": file_v2_id,
                            "name": "draft.txt",
                            "storage_session_id": upload_sid_v2,
                        }
                    ],
                },
                user_id="martin_123",
            )
            self.assertEqual(res3["stdout"], "version-2\n", res3)
            self.assertFalse(tombstone_file.exists())

            # Deleting again + expiring workspace cleans up the tombstone file.
            res4 = mod.execute_code_request(
                {
                    "lang": "py",
                    "session_id": sid,
                    "code": "import os; os.remove('/mnt/data/draft.txt')",
                },
                user_id="martin_123",
            )
            self.assertEqual(res4["deleted_files"], ["draft.txt"])
            self.assertTrue(tombstone_file.is_file())

            now = time.time()
            # Active session preserves tombstones during cleanup.
            mod.cleanup_expired_state(now_ts=now)
            self.assertTrue(tombstone_file.is_file())

            # Expiring the session removes the tombstone file.
            old_ts = now - (40 * 86400)
            ws = mod.workspace_dir_for(sid, "martin_123")
            os.utime(ws, (old_ts, old_ts))
            st_dir = mod.storage_dir_for(sid, "martin_123")
            if st_dir.exists():
                for item in st_dir.iterdir():
                    os.utime(item, (old_ts, old_ts))
            mod.cleanup_expired_state(now_ts=now)
            self.assertFalse(tombstone_file.exists())

    def test_per_user_persistent_cache_mount_env_isolation_and_pruning(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            mod = load_sandbox(
                state,
                SANDBOX_DISABLE_BWRAP="0",
                SANDBOX_CACHE_TTL_DAYS="14",
                SANDBOX_CACHE_MAX_BYTES="100",
            )

            martin_cache = mod.user_cache_dir_for("martin_123")
            louise_cache = mod.user_cache_dir_for("louise_456")
            self.assertIsNotNone(martin_cache)
            self.assertIsNotNone(louise_cache)
            assert martin_cache is not None and louise_cache is not None
            self.assertNotEqual(martin_cache, louise_cache)
            self.assertEqual(martin_cache, state / "users" / "martin_123" / "cache")
            self.assertEqual(martin_cache.stat().st_mode & 0o777, 0o700)

            with mock.patch.object(mod.shutil, "which", return_value="/usr/bin/bwrap"):
                cmd = mod.build_bwrap_cmd(["bash", "-c", "true"], cache_dir=martin_cache)
            self.assertIsNotNone(cmd)
            assert cmd is not None
            tmp_dst_idx = cmd.index("/tmp")
            self.assertEqual(cmd[tmp_dst_idx - 1], "--tmpfs")
            cache_idx = cmd.index("/var/cache/sandbox")
            self.assertEqual(cmd[cache_idx - 2], "--bind")
            self.assertEqual(cmd[cache_idx - 1], str(martin_cache))

            captured_env: dict[str, str] = {}

            def fake_run(bcmd, workspace_dir, env, timeout_sec, tracking_keys=()):
                captured_env.update(env)
                return mod.subprocess.CompletedProcess(bcmd, 0, "", ""), False

            with (
                mock.patch.object(mod.shutil, "which", return_value="/usr/bin/bwrap"),
                mock.patch.object(mod, "_run_process_bounded", side_effect=fake_run),
            ):
                mod.run_sandboxed(
                    ["true"],
                    state,
                    {"PATH": "/bin"},
                    10.0,
                    cache_dir=martin_cache,
                )

            self.assertEqual(captured_env["XDG_CACHE_HOME"], "/var/cache/sandbox/cache")
            self.assertEqual(captured_env["XDG_CONFIG_HOME"], "/var/cache/sandbox/xdg-config")
            self.assertEqual(captured_env["XDG_DATA_HOME"], "/var/cache/sandbox/xdg-data")
            self.assertEqual(captured_env["XDG_STATE_HOME"], "/var/cache/sandbox/xdg-state")
            self.assertEqual(captured_env["NIX_STATE_DIR"], "/var/cache/sandbox/nix-state")
            self.assertEqual(captured_env["GOCACHE"], "/var/cache/sandbox/go-cache")
            self.assertEqual(captured_env["GOMODCACHE"], "/var/cache/sandbox/go-mod")
            self.assertEqual(captured_env["GOPATH"], "/var/cache/sandbox/go")
            self.assertEqual(captured_env["CARGO_HOME"], "/var/cache/sandbox/cargo")
            self.assertEqual(captured_env["UV_CACHE_DIR"], "/var/cache/sandbox/uv-cache")
            self.assertEqual(captured_env["UV_TOOL_DIR"], "/var/cache/sandbox/uv-tools")
            self.assertEqual(captured_env["PIP_CACHE_DIR"], "/var/cache/sandbox/pip-cache")
            self.assertEqual(captured_env["NPM_CONFIG_CACHE"], "/var/cache/sandbox/npm-cache")
            self.assertEqual(captured_env["MPLCONFIGDIR"], "/var/cache/sandbox/matplotlib")
            self.assertEqual(captured_env["CARGO_BUILD_JOBS"], "4")
            self.assertEqual(captured_env["CARGO_INCREMENTAL"], "0")
            self.assertEqual(captured_env["TMPDIR"], "/tmp")
            self.assertEqual(captured_env["GOTMPDIR"], "/tmp")

            # Seed cache files: one expired by TTL, two fresh totalling > 100 bytes.
            now = time.time()
            expired_file = martin_cache / "cargo" / "expired.bin"
            expired_file.parent.mkdir(parents=True, exist_ok=True)
            expired_file.write_bytes(b"a" * 30)
            os.utime(expired_file, (now - 20 * 86400, now - 20 * 86400))

            older_file = martin_cache / "go-cache" / "older.bin"
            older_file.parent.mkdir(parents=True, exist_ok=True)
            older_file.write_bytes(b"b" * 70)
            os.utime(older_file, (now - 3600, now - 3600))

            newer_file = martin_cache / "go-cache" / "newer.bin"
            newer_file.write_bytes(b"c" * 60)
            os.utime(newer_file, (now - 60, now - 60))

            summary = mod.cleanup_expired_state(now_ts=now)
            self.assertEqual(summary["removed_cache_files"], 2)
            self.assertFalse(expired_file.exists())
            self.assertFalse(older_file.exists())
            self.assertTrue(newer_file.is_file())
            self.assertFalse((martin_cache / "cargo").exists())


    def test_unchanged_reinjected_file_preserves_mtime(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            mock.patch.dict(os.environ, {"SANDBOX_DISABLE_BWRAP": "1"}),
        ):
            state = Path(tmp)
            mod = load_sandbox(state)
            upload_sid = mod.to_nanoid("mtime-upload")
            file_id = mod.to_nanoid(f"{upload_sid}:Makefile")
            mod.save_storage_object(
                upload_sid, file_id, "Makefile", b"all:\n\techo hi\n", user_slug="martin_123"
            )
            file_ref = {
                "id": file_id,
                "name": "Makefile",
                "storage_session_id": upload_sid,
            }

            res1 = mod.execute_code_request(
                {"lang": "py", "code": "print('turn1')", "files": [file_ref]},
                user_id="martin_123",
            )
            sid = str(res1["session_id"])
            ws_file = mod.workspace_dir_for(sid, "martin_123") / "Makefile"
            sentinel_ts = 1_700_000_000.0
            os.utime(ws_file, (sentinel_ts, sentinel_ts))

            # Turn 2: re-inject identical blob -> mtime must stay unchanged.
            mod.execute_code_request(
                {
                    "lang": "py",
                    "session_id": sid,
                    "code": "print('turn2')",
                    "files": [file_ref],
                },
                user_id="martin_123",
            )
            self.assertEqual(int(ws_file.stat().st_mtime), int(sentinel_ts))

            # Turn 3: re-inject modified blob -> content and mtime update.
            upload_sid_v2 = mod.to_nanoid("mtime-upload-v2")
            file_id_v2 = mod.to_nanoid(f"{upload_sid_v2}:Makefile")
            mod.save_storage_object(
                upload_sid_v2,
                file_id_v2,
                "Makefile",
                b"all:\n\techo updated\n",
                user_slug="martin_123",
            )
            mod.execute_code_request(
                {
                    "lang": "py",
                    "session_id": sid,
                    "code": "print('turn3')",
                    "files": [
                        {
                            "id": file_id_v2,
                            "name": "Makefile",
                            "storage_session_id": upload_sid_v2,
                        }
                    ],
                },
                user_id="martin_123",
            )
            self.assertEqual(ws_file.read_bytes(), b"all:\n\techo updated\n")
            self.assertGreater(ws_file.stat().st_mtime, sentinel_ts)


class CodeSandboxHttpJwtTests(unittest.TestCase):
    def test_health_unauthenticated(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, _, _, pub_path = make_ed25519_keypair(root)
            with running_sandbox_server(
                root / "state",
                LIBRECHAT_CODE_API_KEY="",
                CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
            ) as (_mod, port):
                status, _headers, body = http_request(port, "GET", "/health")
                self.assertEqual(status, 200)
                self.assertEqual(json.loads(body.decode("utf-8")), {"status": "ok"})

    def test_missing_auth_rejected_on_all_endpoints(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, _, _, pub_path = make_ed25519_keypair(root)
            with running_sandbox_server(
                root / "state",
                LIBRECHAT_CODE_API_KEY="",
                CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
            ) as (mod, port):
                sid = mod.to_nanoid("unauth-session")
                fid = mod.to_nanoid("unauth-file")
                ctype, mbody = build_multipart({}, [("hello.txt", b"hi")])
                checks = [
                    ("POST", "/exec", json.dumps({"lang": "py", "code": "print(1)"}).encode(), {"Content-Type": "application/json"}),
                    ("POST", "/upload", mbody, {"Content-Type": ctype}),
                    ("GET", f"/files/{sid}", None, {}),
                    ("GET", f"/download/{sid}/{fid}", None, {}),
                    ("DELETE", f"/files/{sid}/{fid}", None, {}),
                ]
                for method, path, body, headers in checks:
                    status, _h, _b = http_request(port, method, path, body=body, headers=headers)
                    self.assertEqual(status, 401, f"{method} {path} should require auth")

    def test_invalid_jwts_and_static_api_key_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            priv, _, _, pub_path = make_ed25519_keypair(root)
            other_priv = Ed25519PrivateKey.generate()
            valid_token = mint_jwt(priv)
            parts = valid_token.split(".")
            tampered_payload = _b64url(
                json.dumps(
                    {
                        "iss": "librechat",
                        "aud": "codeapi",
                        "sub": "other_user",
                        "exp": int(time.time()) + 300,
                    }
                ).encode("utf-8")
            )
            tampered_token = f"{parts[0]}.{tampered_payload}.{parts[2]}"

            invalid_cases: list[tuple[str, dict[str, str]]] = [
                ("wrong-key", {"Authorization": f"Bearer {mint_jwt(other_priv)}"}),
                ("tampered", {"Authorization": f"Bearer {tampered_token}"}),
                ("wrong-alg-rs256", {"Authorization": f"Bearer {mint_jwt(priv, alg='RS256')}"}),
                ("wrong-alg-none", {"Authorization": f"Bearer {mint_jwt(priv, alg='none')}"}),
                ("wrong-iss", {"Authorization": f"Bearer {mint_jwt(priv, iss='other-issuer')}"}),
                ("wrong-aud", {"Authorization": f"Bearer {mint_jwt(priv, aud='other-aud')}"}),
                ("expired", {"Authorization": f"Bearer {mint_jwt(priv, exp_offset=-120)}"}),
                ("future-nbf", {"Authorization": f"Bearer {mint_jwt(priv, nbf_offset=120)}"}),
                ("missing-sub", {"Authorization": f"Bearer {mint_jwt(priv, omit_claims=('sub',))}"}),
                ("empty-sub", {"Authorization": f"Bearer {mint_jwt(priv, sub='   ')}"}),
                ("static-x-api-key", {"X-API-Key": "local-sandbox"}),
                ("static-bearer", {"Authorization": "Bearer local-sandbox"}),
            ]

            with running_sandbox_server(
                root / "state",
                LIBRECHAT_CODE_API_KEY="",
                CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
            ) as (_mod, port):
                payload = json.dumps({"lang": "py", "code": "print(1)"}).encode("utf-8")
                for label, extra_headers in invalid_cases:
                    headers = {"Content-Type": "application/json", **extra_headers}
                    status, _h, _b = http_request(port, "POST", "/exec", body=payload, headers=headers)
                    self.assertEqual(status, 401, f"case {label} must return 401")

    def test_valid_jwt_full_lifecycle_without_user_id_header(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            state_dir = root / "state"
            priv, _, _, pub_path = make_ed25519_keypair(root)
            token = mint_jwt(priv, sub="martin_123")
            list_aud_token = mint_jwt(priv, sub="martin_123", aud=["other", "codeapi"])

            with running_sandbox_server(
                state_dir,
                LIBRECHAT_CODE_API_KEY="",
                CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
            ) as (mod, port):
                # POST /exec with no User-Id header.
                exec_body = json.dumps(
                    {
                        "lang": "py",
                        "code": "open('/mnt/data/report.txt', 'w').write('hello jwt')",
                    }
                ).encode("utf-8")
                status, _h, raw = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=exec_body,
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {token}",
                    },
                )
                self.assertEqual(status, 200, raw)
                exec_res = json.loads(raw.decode("utf-8"))
                sid = exec_res["session_id"]
                self.assertEqual(mod.get_session_owner(sid), "martin_123")
                self.assertEqual(len(exec_res["files"]), 1)
                report_fid = exec_res["files"][0]["id"]

                # POST /upload into the same session with no User-Id header.
                ctype, mbody = build_multipart(
                    {"session_id": sid},
                    [("uploaded.txt", b"uploaded-bytes")],
                )
                status, _h, raw = http_request(
                    port,
                    "POST",
                    "/upload",
                    body=mbody,
                    headers={
                        "Content-Type": ctype,
                        "Authorization": f"Bearer {list_aud_token}",
                    },
                )
                self.assertEqual(status, 200, raw)
                up_res = json.loads(raw.decode("utf-8"))
                self.assertEqual(up_res["storage_session_id"], sid)
                uploaded_fid = up_res["files"][0]["fileId"]

                # GET /files/<session> with no User-Id header.
                status, _h, raw = http_request(
                    port,
                    "GET",
                    f"/files/{sid}",
                    headers={"Authorization": f"Bearer {token}"},
                )
                self.assertEqual(status, 200, raw)
                listed_names = {item["name"] for item in json.loads(raw.decode("utf-8"))}
                self.assertEqual(listed_names, {"report.txt", "uploaded.txt"})

                # GET /download/<session>/<file> with no User-Id header.
                status, _h, raw = http_request(
                    port,
                    "GET",
                    f"/download/{sid}/{report_fid}",
                    headers={"Authorization": f"Bearer {token}"},
                )
                self.assertEqual(status, 200)
                self.assertEqual(raw, b"hello jwt")

                status, _h, raw = http_request(
                    port,
                    "GET",
                    f"/download/{sid}/{uploaded_fid}",
                    headers={"Authorization": f"Bearer {token}"},
                )
                self.assertEqual(status, 200)
                self.assertEqual(raw, b"uploaded-bytes")

                # DELETE /files/<session>/<file> with no User-Id header.
                status, _h, raw = http_request(
                    port,
                    "DELETE",
                    f"/files/{sid}/{report_fid}",
                    headers={"Authorization": f"Bearer {token}"},
                )
                self.assertEqual(status, 200, raw)

                status, _h, _raw = http_request(
                    port,
                    "GET",
                    f"/download/{sid}/{report_fid}",
                    headers={"Authorization": f"Bearer {token}"},
                )
                self.assertEqual(status, 404)

    def test_cross_user_jwt_isolation_ignores_spoofed_headers(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            priv, _, _, pub_path = make_ed25519_keypair(root)
            owner_token = mint_jwt(priv, sub="martin_123")
            attacker_token = mint_jwt(priv, sub="louise_456")

            with running_sandbox_server(
                root / "state",
                LIBRECHAT_CODE_API_KEY="",
                CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
            ) as (_mod, port):
                status, _h, raw = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=json.dumps(
                        {
                            "lang": "py",
                            "code": "open('/mnt/data/secret.txt', 'w').write('owner-only')",
                        }
                    ).encode("utf-8"),
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {owner_token}",
                    },
                )
                self.assertEqual(status, 200, raw)
                owner_res = json.loads(raw.decode("utf-8"))
                sid = owner_res["session_id"]
                fid = owner_res["files"][0]["id"]

                spoofed_headers = {
                    "Authorization": f"Bearer {attacker_token}",
                    "User-Id": "martin_123",
                    "X-User-Id": "martin_123",
                }

                # Cross-user POST /exec with spoofed headers and body user_id -> 403.
                status, _h, _raw = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=json.dumps(
                        {
                            "lang": "py",
                            "code": "print('pwned')",
                            "session_id": sid,
                            "user_id": "martin_123",
                        }
                    ).encode("utf-8"),
                    headers={"Content-Type": "application/json", **spoofed_headers},
                )
                self.assertEqual(status, 403)

                # Cross-user POST /upload into owner's session -> 403.
                ctype, mbody = build_multipart(
                    {"session_id": sid}, [("evil.txt", b"overwrite")]
                )
                status, _h, _raw = http_request(
                    port,
                    "POST",
                    "/upload",
                    body=mbody,
                    headers={"Content-Type": ctype, **spoofed_headers},
                )
                self.assertEqual(status, 403)

                # Cross-user GET /files, GET /download, DELETE /files -> 403.
                for method, path in (
                    ("GET", f"/files/{sid}"),
                    ("GET", f"/download/{sid}/{fid}"),
                    ("DELETE", f"/files/{sid}/{fid}"),
                ):
                    status, _h, _raw = http_request(
                        port, method, path, headers=spoofed_headers
                    )
                    self.assertEqual(status, 403, f"cross-user {method} {path} must return 403")

                # Owner can still download intact file.
                status, _h, raw = http_request(
                    port,
                    "GET",
                    f"/download/{sid}/{fid}",
                    headers={"Authorization": f"Bearer {owner_token}"},
                )
                self.assertEqual(status, 200)
                self.assertEqual(raw, b"owner-only")

    def test_missing_public_key_fails_closed_and_rotation_reloads(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pub_path = root / "public.pem"
            priv1 = Ed25519PrivateKey.generate()
            pub1_bytes = priv1.public_key().public_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            priv2 = Ed25519PrivateKey.generate()
            pub2_bytes = priv2.public_key().public_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            token1 = mint_jwt(priv1, sub="martin_123")
            token2 = mint_jwt(priv2, sub="martin_123")
            body = json.dumps({"lang": "py", "code": "print(1)"}).encode("utf-8")

            with running_sandbox_server(
                root / "state",
                LIBRECHAT_CODE_API_KEY="",
                CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
            ) as (_mod, port):
                # Missing public key file must fail closed (401).
                status, _h, _r = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=body,
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {token1}",
                    },
                )
                self.assertEqual(status, 401)

                # Write key 1 -> token 1 succeeds.
                tmp_key = root / "public.pem.tmp"
                tmp_key.write_bytes(pub1_bytes)
                os.replace(tmp_key, pub_path)
                status, _h, _r = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=body,
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {token1}",
                    },
                )
                self.assertEqual(status, 200)

                # Atomically rotate to key 2 -> token 1 fails, token 2 succeeds.
                tmp_key.write_bytes(pub2_bytes)
                os.replace(tmp_key, pub_path)
                status1, _h, _r = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=body,
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {token1}",
                    },
                )
                status2, _h, _r = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=body,
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {token2}",
                    },
                )
                self.assertEqual(status1, 401)
                self.assertEqual(status2, 200)

    def test_pkcs8_base64_key_roundtrip_matches_librechat_codeapi(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, _, private_pem_b64, pub_path = make_ed25519_keypair(root)
            # LibreChat's codeapi.ts decodes CODEAPI_JWT_PRIVATE_KEY_BASE64 via
            # normalizePem(Buffer.from(base64Key, 'base64').toString('utf8')).
            decoded_pem = (
                base64.b64decode(private_pem_b64).decode("utf-8").replace("\\n", "\n").strip()
            )
            reloaded = serialization.load_pem_private_key(
                decoded_pem.encode("utf-8"), password=None
            )
            self.assertIsInstance(reloaded, Ed25519PrivateKey)
            assert isinstance(reloaded, Ed25519PrivateKey)
            token = mint_jwt(reloaded, sub="65f1a2b3c4d5e6f7a8b9c0d1")

            with running_sandbox_server(
                root / "state",
                LIBRECHAT_CODE_API_KEY="",
                CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
            ) as (_mod, port):
                status, _h, raw = http_request(
                    port,
                    "POST",
                    "/exec",
                    body=json.dumps({"lang": "py", "code": "print('ok')"}).encode("utf-8"),
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {token}",
                    },
                )
                self.assertEqual(status, 200, raw)
                self.assertEqual(json.loads(raw.decode("utf-8"))["stdout"], "ok\n")

    def test_gh_token_injected_only_for_admin_jwt_and_never_for_user_or_api_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            priv, _, _, pub_path = make_ed25519_keypair(root)
            cred_dir = root / "creds"
            cred_dir.mkdir()
            (cred_dir / "GH_TOKEN").write_text("ghp_secret_admin_token\n", encoding="utf-8")

            admin_token = mint_jwt(priv, sub="martin_123", extra_claims={"role": "ADMIN"})
            user_token = mint_jwt(priv, sub="louise_456", extra_claims={"role": "USER"})
            no_role_token = mint_jwt(priv, sub="agatha_789", omit_claims=("role",))
            probe_body = json.dumps(
                {
                    "lang": "py",
                    "code": "import os; print(os.environ.get('GH_TOKEN', '<MISSING>'))",
                }
            ).encode("utf-8")

            # Production path via CREDENTIALS_DIRECTORY with JWT auth.
            with mock.patch.dict(
                os.environ,
                {"CREDENTIALS_DIRECTORY": str(cred_dir), "SANDBOX_GH_TOKEN_FILE": ""},
                clear=False,
            ):
                with running_sandbox_server(
                    root / "state-jwt",
                    LIBRECHAT_CODE_API_KEY="",
                    CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
                ) as (_mod, port):
                    status, _h, raw = http_request(
                        port,
                        "POST",
                        "/exec",
                        body=probe_body,
                        headers={
                            "Content-Type": "application/json",
                            "Authorization": f"Bearer {admin_token}",
                        },
                    )
                    self.assertEqual(status, 200, raw)
                    self.assertEqual(
                        json.loads(raw.decode("utf-8"))["stdout"],
                        "ghp_secret_admin_token\n",
                    )

                    for tok in (user_token, no_role_token):
                        status, _h, raw = http_request(
                            port,
                            "POST",
                            "/exec",
                            body=probe_body,
                            headers={
                                "Content-Type": "application/json",
                                "Authorization": f"Bearer {tok}",
                            },
                        )
                        self.assertEqual(status, 200, raw)
                        self.assertEqual(
                            json.loads(raw.decode("utf-8"))["stdout"],
                            "<MISSING>\n",
                        )

            # Static X-API-Key fallback mode with SANDBOX_GH_TOKEN_FILE must NEVER inject GH_TOKEN.
            with mock.patch.dict(
                os.environ,
                {
                    "SANDBOX_GH_TOKEN_FILE": str(cred_dir / "GH_TOKEN"),
                    "CREDENTIALS_DIRECTORY": "",
                },
                clear=False,
            ):
                with running_sandbox_server(
                    root / "state-apikey",
                    LIBRECHAT_CODE_API_KEY="static-key",
                    CODEAPI_JWT_PUBLIC_KEY="",
                    CODEAPI_JWT_PUBLIC_KEY_FILE="",
                ) as (_mod, port):
                    status, _h, raw = http_request(
                        port,
                        "POST",
                        "/exec",
                        body=probe_body,
                        headers={
                            "Content-Type": "application/json",
                            "X-API-Key": "static-key",
                            "User-Id": "martin_123",
                        },
                    )
                    self.assertEqual(status, 200, raw)
                    self.assertEqual(
                        json.loads(raw.decode("utf-8"))["stdout"],
                        "<MISSING>\n",
                    )

    def test_cloudflare_credentials_injected_only_for_admin_jwt(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            priv, _, _, pub_path = make_ed25519_keypair(root)
            cred_dir = root / "creds"
            cred_dir.mkdir()
            (cred_dir / "CLOUDFLARE_ACCOUNT_ID").write_text(
                "cf_acct_admin_123\n", encoding="utf-8"
            )
            (cred_dir / "CLOUDFLARE_API_TOKEN").write_text(
                "cf_tok_admin_456\n", encoding="utf-8"
            )

            admin_token = mint_jwt(priv, sub="martin_123", extra_claims={"role": "ADMIN"})
            user_token = mint_jwt(priv, sub="louise_456", extra_claims={"role": "USER"})
            no_role_token = mint_jwt(priv, sub="agatha_789", omit_claims=("role",))
            probe_body = json.dumps(
                {
                    "lang": "py",
                    "code": (
                        "import json, os; print(json.dumps({"
                        "'acct': os.environ.get('CLOUDFLARE_ACCOUNT_ID'), "
                        "'tok': os.environ.get('CLOUDFLARE_API_TOKEN')"
                        "}))"
                    ),
                }
            ).encode("utf-8")

            with mock.patch.dict(
                os.environ,
                {
                    "CREDENTIALS_DIRECTORY": str(cred_dir),
                    "SANDBOX_CLOUDFLARE_ACCOUNT_ID_FILE": "",
                    "SANDBOX_CLOUDFLARE_API_TOKEN_FILE": "",
                },
                clear=False,
            ):
                with running_sandbox_server(
                    root / "state-cf-jwt",
                    LIBRECHAT_CODE_API_KEY="",
                    CODEAPI_JWT_PUBLIC_KEY_FILE=str(pub_path),
                ) as (_mod, port):
                    status, _h, raw = http_request(
                        port,
                        "POST",
                        "/exec",
                        body=probe_body,
                        headers={
                            "Content-Type": "application/json",
                            "Authorization": f"Bearer {admin_token}",
                        },
                    )
                    self.assertEqual(status, 200, raw)
                    self.assertEqual(
                        json.loads(json.loads(raw.decode("utf-8"))["stdout"]),
                        {"acct": "cf_acct_admin_123", "tok": "cf_tok_admin_456"},
                    )

                    for tok in (user_token, no_role_token):
                        status, _h, raw = http_request(
                            port,
                            "POST",
                            "/exec",
                            body=probe_body,
                            headers={
                                "Content-Type": "application/json",
                                "Authorization": f"Bearer {tok}",
                            },
                        )
                        self.assertEqual(status, 200, raw)
                        self.assertEqual(
                            json.loads(json.loads(raw.decode("utf-8"))["stdout"]),
                            {"acct": None, "tok": None},
                        )

            # Static X-API-Key mode must NEVER inject Cloudflare credentials.
            with mock.patch.dict(
                os.environ,
                {
                    "CREDENTIALS_DIRECTORY": "",
                    "SANDBOX_CLOUDFLARE_ACCOUNT_ID_FILE": str(
                        cred_dir / "CLOUDFLARE_ACCOUNT_ID"
                    ),
                    "SANDBOX_CLOUDFLARE_API_TOKEN_FILE": str(
                        cred_dir / "CLOUDFLARE_API_TOKEN"
                    ),
                },
                clear=False,
            ):
                with running_sandbox_server(
                    root / "state-cf-apikey",
                    LIBRECHAT_CODE_API_KEY="static-key",
                    CODEAPI_JWT_PUBLIC_KEY="",
                    CODEAPI_JWT_PUBLIC_KEY_FILE="",
                ) as (_mod, port):
                    status, _h, raw = http_request(
                        port,
                        "POST",
                        "/exec",
                        body=probe_body,
                        headers={
                            "Content-Type": "application/json",
                            "X-API-Key": "static-key",
                            "User-Id": "martin_123",
                        },
                    )
                    self.assertEqual(status, 200, raw)
                    self.assertEqual(
                        json.loads(json.loads(raw.decode("utf-8"))["stdout"]),
                        {"acct": None, "tok": None},
                    )


if __name__ == "__main__":
    unittest.main()
