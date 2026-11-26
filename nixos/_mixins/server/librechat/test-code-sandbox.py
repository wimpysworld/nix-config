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


if __name__ == "__main__":
    unittest.main()
