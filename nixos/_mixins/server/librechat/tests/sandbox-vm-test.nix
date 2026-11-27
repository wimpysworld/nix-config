# Run by checks.x86_64-linux.librechat-code-sandbox-vm. Verifies
# librechat-code-sandbox.service end-to-end on a real Linux kernel with
# bubblewrap, pasta network isolation, systemd hardening, and iptables rules.
{
  pkgs,
}:
let
  inherit (pkgs) lib;
  serverPython = pkgs.python3.withPackages (ps: [ ps.cryptography ]);

  sandboxEtc = pkgs.runCommand "librechat-sandbox-vm-etc" { } ''
    mkdir -p "$out/fonts/2.11" "$out/nix" "$out/ssl/certs"

    cat > "$out/hosts" <<'EOF'
    127.0.0.1 localhost sandbox
    ::1 localhost sandbox
    EOF

    cat > "$out/resolv.conf" <<'EOF'
    nameserver 1.1.1.1
    nameserver 9.9.9.9
    options edns0 trust-ad
    EOF

    cat > "$out/nsswitch.conf" <<'EOF'
    passwd: files
    group: files
    hosts: files dns
    networks: files
    services: files
    protocols: files
    EOF

    ln -s ${pkgs.iana-etc}/etc/protocols "$out/protocols"
    ln -s ${pkgs.iana-etc}/etc/services "$out/services"
    ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt "$out/ssl/certs/ca-bundle.crt"
    ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt "$out/ssl/certs/ca-certificates.crt"
    ln -s ${pkgs.tzdata}/share/zoneinfo/UTC "$out/localtime"
    ln -s ${pkgs.tzdata}/share/zoneinfo "$out/zoneinfo"

    : > "$out/passwd"
    : > "$out/group"
  '';

  sandboxAdminGitConfig = pkgs.writeText "librechat-sandbox-vm-gitconfig" ''
    [user]
      name = Martin Wimpress
      email = code@wimpress.io
    [init]
      defaultBranch = main
    [safe]
      directory = *
  '';

  hostOnlyMarker = pkgs.writeText "librechat-sandbox-host-only-marker" "host-only-secret-marker\n";

  sandboxPathPackages = [
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.git
    pkgs.hostname
    pkgs.procps
    pkgs.python3
    pkgs.util-linux
  ];

  sandboxClosure = pkgs.closureInfo {
    rootPaths = sandboxPathPackages ++ [
      sandboxEtc
      sandboxAdminGitConfig
      pkgs.cacert
      pkgs.tzdata
      pkgs.iana-etc
    ];
  };

  librechatCodeApiKeygen = pkgs.writeShellApplication {
    name = "librechat-codeapi-keygen";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
    ];
    text = ''
      keyDir="/var/lib/librechat-codeapi-keys"
      privatePem="$keyDir/private.pem"
      privateB64="$keyDir/private.pem.b64"
      publicPem="$keyDir/public.pem"

      if [ -s "$privateB64" ] && [ -s "$publicPem" ]; then
        exit 0
      fi

      umask 077
      tmpDir="$(mktemp -d "$keyDir/.keygen.XXXXXX")"
      cleanup() {
        rm -rf "$tmpDir"
      }
      trap cleanup EXIT

      if [ -s "$privatePem" ]; then
        cp "$privatePem" "$tmpDir/private.pem"
      else
        openssl genpkey -algorithm ED25519 -out "$tmpDir/private.pem"
      fi

      openssl pkey -in "$tmpDir/private.pem" -pubout -out "$tmpDir/public.pem"
      base64 -w 0 "$tmpDir/private.pem" > "$tmpDir/private.pem.b64"

      chmod 0600 "$tmpDir/private.pem" "$tmpDir/private.pem.b64"
      chmod 0644 "$tmpDir/public.pem"

      if [ ! -s "$privatePem" ]; then
        mv -f "$tmpDir/private.pem" "$privatePem"
      fi
      mv -f "$tmpDir/private.pem.b64" "$privateB64"
      mv -f "$tmpDir/public.pem" "$publicPem"
    '';
  };

  librechatCodeSandbox = pkgs.runCommand "librechat-code-sandbox-vm-bin" { } ''
    install -Dm755 ${../code-sandbox.py} "$out/libexec/code-sandbox.py"
  '';

  hostProbeListener = pkgs.writeScript "host-probe-listener" ''
    #!${lib.getExe pkgs.python3}
    import http.server
    import socket
    import threading

    class QuietHandler(http.server.BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            return
        def do_GET(self):
            body = b"host-loopback-secret\n"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    class HTTPServerV6(http.server.HTTPServer):
        address_family = socket.AF_INET6

    def serve_abstract_unix():
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind("\0host-test-abstract")
        sock.listen(8)
        while True:
            conn, _ = sock.accept()
            with conn:
                conn.sendall(b"host-abstract-secret\n")

    s4 = http.server.HTTPServer(("127.0.0.1", 18080), QuietHandler)
    s6 = HTTPServerV6(("::1", 18080), QuietHandler)
    threading.Thread(target=s4.serve_forever, daemon=True).start()
    threading.Thread(target=s6.serve_forever, daemon=True).start()
    serve_abstract_unix()
  '';

  remoteHttpServer = pkgs.writeScript "remote-http-server" ''
    #!${lib.getExe pkgs.python3}
    import http.server

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            return
        def do_GET(self):
            body = b"remote-egress-ok\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    http.server.HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
  '';

  sandboxVerifier = pkgs.writeText "verify-librechat-sandbox.py" ''
    import base64
    import http.client
    import json
    import subprocess
    import time
    from pathlib import Path
    from cryptography.hazmat.primitives import serialization

    HOST_ONLY_MARKER = "${hostOnlyMarker}"
    ADMIN_GIT_CONFIG = "${sandboxAdminGitConfig}"

    def b64url(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")

    priv_pem = Path("/var/lib/librechat-codeapi-keys/private.pem").read_bytes()
    priv_key = serialization.load_pem_private_key(priv_pem, password=None)

    def mint_jwt(sub: str, role: str) -> str:
        now = int(time.time())
        header = {"alg": "EdDSA", "typ": "JWT", "kid": "vm-test"}
        claims = {
            "iss": "librechat",
            "aud": "codeapi",
            "sub": sub,
            "role": role,
            "iat": now,
            "nbf": now,
            "exp": now + 300,
        }
        h = b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
        p = b64url(json.dumps(claims, separators=(",", ":")).encode("utf-8"))
        sig = priv_key.sign(f"{h}.{p}".encode("ascii"))
        return f"{h}.{p}.{b64url(sig)}"

    def http_call(method: str, path: str, body: bytes | None = None, headers: dict[str, str] | None = None):
        conn = http.client.HTTPConnection("127.0.0.1", 3082, timeout=30)
        try:
            conn.request(method, path, body=body, headers=headers or {})
            resp = conn.getresponse()
            data = resp.read()
            return resp.status, data
        finally:
            conn.close()

    def exec_code(token: str, lang: str, code: str, **extra):
        payload = {"lang": lang, "code": code, **extra}
        status, raw = http_call(
            "POST",
            "/exec",
            body=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
            },
        )
        assert status == 200, f"HTTP {status}: {raw!r}"
        return json.loads(raw.decode("utf-8"))

    def upload_file(token: str, filename: str, content: bytes, session_id: str | None = None):
        boundary = "----VMSandboxUploadBoundary"
        parts = []
        if session_id:
            parts.append(
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="session_id"\r\n\r\n'
                f"{session_id}\r\n".encode("utf-8")
            )
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            f"Content-Type: application/octet-stream\r\n\r\n".encode("utf-8")
            + content
            + b"\r\n"
        )
        parts.append(f"--{boundary}--\r\n".encode("utf-8"))
        status, raw = http_call(
            "POST",
            "/upload",
            body=b"".join(parts),
            headers={
                "Content-Type": f"multipart/form-data; boundary={boundary}",
                "Authorization": f"Bearer {token}",
            },
        )
        assert status == 200, f"upload HTTP {status}: {raw!r}"
        return json.loads(raw.decode("utf-8"))

    def assert_no_pasta_processes(context: str):
        res = subprocess.run(["pgrep", "-a", "pasta"], capture_output=True, text=True, check=False)
        assert res.returncode != 0, f"lingering pasta processes after {context}: {res.stdout!r}"

    admin_tok = mint_jwt("martin_admin", "ADMIN")
    user_tok = mint_jwt("louise_user", "USER")

    # 1. Basic execution.
    r1 = exec_code(user_tok, "bash", "echo hello")
    assert r1["stdout"] == "hello\n", f"unexpected stdout: {r1}"
    assert r1["stderr"] == "", f"unexpected stderr: {r1}"
    assert_no_pasta_processes("basic execution")

    # 2. Identity & hardening.
    probe_hardening = (
        "import json, os, subprocess\n"
        "from pathlib import Path\n"
        "status = {}\n"
        "for line in Path('/proc/self/status').read_text().splitlines():\n"
        "    if ':' in line:\n"
        "        k, v = line.split(':', 1)\n"
        "        status[k.strip()] = v.strip()\n"
        "ro_failed = False\n"
        "try:\n"
        "    Path('/nope').write_text('x')\n"
        "except OSError:\n"
        "    ro_failed = True\n"
        "st_tmp = os.statvfs('/tmp')\n"
        "st_shm = os.statvfs('/dev/shm')\n"
        "print(json.dumps({\n"
        "    'id_un': subprocess.check_output(['id', '-un'], text=True).strip(),\n"
        "    'hostname': subprocess.check_output(['uname', '-n'], text=True).strip(),\n"
        "    'cap_eff': status.get('CapEff'),\n"
        "    'no_new_privs': status.get('NoNewPrivs'),\n"
        "    'ro_failed': ro_failed,\n"
        "    'tmp_bytes': st_tmp.f_frsize * st_tmp.f_blocks,\n"
        "    'shm_bytes': st_shm.f_frsize * st_shm.f_blocks,\n"
        "    'current_system_exists': Path('/run/current-system').exists(),\n"
        "    'passwd_lines': Path('/etc/passwd').read_text().splitlines(),\n"
        "    'resolv_conf': Path('/etc/resolv.conf').read_text(),\n"
        f"    'host_marker_exists': Path({HOST_ONLY_MARKER!r}).exists(),\n"
        "}))\n"
    )
    r2 = exec_code(user_tok, "py", probe_hardening)
    assert r2["stderr"] == "", f"hardening probe stderr: {r2}"
    h = json.loads(r2["stdout"])
    assert h["id_un"] == "librechat-code-sandbox", h
    assert h["hostname"] == "sandbox", h
    assert h["cap_eff"] == "0000000000000000", h
    assert h["no_new_privs"] == "1", h
    assert h["ro_failed"] is True, h
    assert h["tmp_bytes"] == 4294967296, h
    assert h["shm_bytes"] == 536870912, h
    assert h["current_system_exists"] is False, h
    assert len(h["passwd_lines"]) == 2, h
    assert "1.1.1.1" in h["resolv_conf"], h
    assert h["host_marker_exists"] is False, h

    # 3. Real pasta network isolation + working egress.
    probe_net = (
        "import json, socket, time, urllib.request\n"
        "from pathlib import Path\n"
        "proc_tcp = Path('/proc/net/tcp').read_text()\n"
        "def try_tcp(family, addr, port, timeout=3.0):\n"
        "    t0 = time.monotonic()\n"
        "    s = socket.socket(family, socket.SOCK_STREAM)\n"
        "    s.settimeout(timeout)\n"
        "    try:\n"
        "        s.connect((addr, port))\n"
        "        return {'ok': True, 'ms': int((time.monotonic() - t0) * 1000)}\n"
        "    except OSError as exc:\n"
        "        return {'ok': False, 'err': str(exc), 'ms': int((time.monotonic() - t0) * 1000)}\n"
        "    finally:\n"
        "        s.close()\n"
        "def try_abstract():\n"
        "    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n"
        "    s.settimeout(2.0)\n"
        "    try:\n"
        "        s.connect('\\0host-test-abstract')\n"
        "        return True\n"
        "    except OSError:\n"
        "        return False\n"
        "    finally:\n"
        "        s.close()\n"
        "with urllib.request.urlopen('http://198.51.100.2:8080/', timeout=5) as resp:\n"
        "    remote_status = resp.status\n"
        "    remote_body = resp.read().decode('utf-8')\n"
        "print(json.dumps({\n"
        "    'has_18080': ':46A0' in proc_tcp,\n"
        "    'has_3082': ':0C0A' in proc_tcp,\n"
        "    'loopback_v4': try_tcp(socket.AF_INET, '127.0.0.1', 18080),\n"
        "    'loopback_v6': try_tcp(socket.AF_INET6, '::1', 18080),\n"
        "    'ula_v6': try_tcp(socket.AF_INET6, 'fc00::1', 18080),\n"
        "    'rfc1918_v4': try_tcp(socket.AF_INET, '10.255.255.1', 80),\n"
        "    'abstract_unix': try_abstract(),\n"
        "    'remote_status': remote_status,\n"
        "    'remote_body': remote_body,\n"
        "}))\n"
    )
    r3 = exec_code(user_tok, "py", probe_net)
    assert r3["stderr"] == "", f"network probe stderr: {r3}"
    net = json.loads(r3["stdout"])
    assert net["has_18080"] is False, net
    assert net["has_3082"] is False, net
    assert net["loopback_v4"]["ok"] is False, net
    assert net["abstract_unix"] is False, net
    assert net["remote_status"] == 200, net
    assert net["remote_body"] == "remote-egress-ok\n", net
    assert net["loopback_v6"]["ok"] is False and net["loopback_v6"]["ms"] < 500, net
    assert net["ula_v6"]["ok"] is False and net["ula_v6"]["ms"] < 500, net
    assert net["rfc1918_v4"]["ok"] is False and net["rfc1918_v4"]["ms"] < 500, net

    # 4. Multi-turn persistence, .git, deletion tombstones, and /var/cache/sandbox.
    up = upload_file(user_tok, "draft.txt", b"initial-draft\n")
    draft_ref = {
        "id": up["files"][0]["fileId"],
        "name": "draft.txt",
        "storage_session_id": up["storage_session_id"],
    }
    t1 = exec_code(
        user_tok,
        "bash",
        "mkdir -p .git && echo 'ref: refs/heads/main' > .git/HEAD && "
        "echo 'turn-one' > note.txt && "
        "echo 'cached-value' > /var/cache/sandbox/persisted.txt && "
        "rm -f /mnt/data/draft.txt",
        files=[draft_ref],
    )
    assert t1["stderr"] == "", t1
    sid = t1["session_id"]
    assert [f["name"] for f in t1["files"]] == ["note.txt"], t1
    assert t1["deleted_files"] == ["draft.txt"], t1

    t2 = exec_code(
        user_tok,
        "py",
        "import json; from pathlib import Path; print(json.dumps({"
        "'note': Path('/mnt/data/note.txt').read_text().strip(), "
        "'git': Path('/mnt/data/.git/HEAD').read_text().strip(), "
        "'draft_exists': Path('/mnt/data/draft.txt').exists(), "
        "'cache': Path('/var/cache/sandbox/persisted.txt').read_text().strip()"
        "}))",
        session_id=sid,
        files=[draft_ref],
    )
    assert t2["stderr"] == "", t2
    p2 = json.loads(t2["stdout"])
    assert p2 == {
        "note": "turn-one",
        "git": "ref: refs/heads/main",
        "draft_exists": False,
        "cache": "cached-value",
    }, p2

    # Separate session for the same user still sees /var/cache/sandbox.
    t3 = exec_code(user_tok, "bash", "cat /var/cache/sandbox/persisted.txt")
    assert t3["stdout"] == "cached-value\n", t3

    # 5. Role gating: ADMIN vs USER credentials and GIT_CONFIG_SYSTEM.
    role_probe = (
        "import json, os; from pathlib import Path; "
        "gc = os.environ.get('GIT_CONFIG_SYSTEM'); "
        "print(json.dumps({"
        "'GH_TOKEN': os.environ.get('GH_TOKEN'), "
        "'CLOUDFLARE_ACCOUNT_ID': os.environ.get('CLOUDFLARE_ACCOUNT_ID'), "
        "'CLOUDFLARE_API_TOKEN': os.environ.get('CLOUDFLARE_API_TOKEN'), "
        "'GIT_CONFIG_SYSTEM': gc, "
        "'git_config_readable': bool(gc and Path(gc).is_file())"
        "}))"
    )
    ra = exec_code(admin_tok, "py", role_probe)
    assert ra["stderr"] == "", ra
    assert json.loads(ra["stdout"]) == {
        "GH_TOKEN": "ghp_vm_test_token",
        "CLOUDFLARE_ACCOUNT_ID": "cf_vm_test_account",
        "CLOUDFLARE_API_TOKEN": "cf_vm_test_token",
        "GIT_CONFIG_SYSTEM": ADMIN_GIT_CONFIG,
        "git_config_readable": True,
    }, ra

    ru = exec_code(user_tok, "py", role_probe)
    assert ru["stderr"] == "", ru
    assert json.loads(ru["stdout"]) == {
        "GH_TOKEN": None,
        "CLOUDFLARE_ACCOUNT_ID": None,
        "CLOUDFLARE_API_TOKEN": None,
        "GIT_CONFIG_SYSTEM": None,
        "git_config_readable": False,
    }, ru

    # 6. Nested userns blocked (--disable-userns).
    userns_probe = (
        "import ctypes, json, subprocess\n"
        "cli = subprocess.run(['unshare', '-Ur', 'true'], capture_output=True, text=True)\n"
        "libc = ctypes.CDLL('libc.so.6', use_errno=True)\n"
        "CLONE_NEWUSER = 0x10000000\n"
        "rc = libc.unshare(CLONE_NEWUSER)\n"
        "errno_val = ctypes.get_errno()\n"
        "print(json.dumps({\n"
        "    'cli_rc': cli.returncode,\n"
        "    'syscall_rc': rc,\n"
        "    'syscall_errno': errno_val,\n"
        "}))\n"
    )
    r6 = exec_code(user_tok, "py", userns_probe)
    assert r6["stderr"] == "", r6
    u = json.loads(r6["stdout"])
    assert u["cli_rc"] != 0, u
    assert u["syscall_rc"] == -1, u
    assert u["syscall_errno"] != 0, u

    # 7. Process hygiene after normal completion and after a 2-second timeout.
    assert_no_pasta_processes("role and userns checks")
    rt = exec_code(user_tok, "bash", "sleep 30", timeout=2)
    assert "Execution timed out." in rt["stderr"], rt
    assert_no_pasta_processes("2-second timeout")

    print("ALL_VM_SANDBOX_CHECKS_PASSED")
  '';
in
pkgs.testers.runNixOSTest {
  name = "librechat-code-sandbox-vm";

  nodes = {
    remote =
      { ... }:
      {
        virtualisation.vlans = [ 1 ];
        networking.useDHCP = false;
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "198.51.100.2";
            prefixLength = 24;
          }
        ];
        networking.firewall.allowedTCPPorts = [ 8080 ];
        systemd.services.remote-http = {
          description = "External HTTP test endpoint";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${remoteHttpServer}";
          };
        };
      };

    sandbox =
      { ... }:
      {
        virtualisation = {
          memorySize = 1024;
          vlans = [ 1 ];
        };

        networking = {
          useDHCP = false;
          interfaces.eth1 = {
            ipv4.addresses = lib.mkForce [
              {
                address = "198.51.100.1";
                prefixLength = 24;
              }
            ];
            ipv6.addresses = lib.mkForce [
              {
                address = "2001:db8::1";
                prefixLength = 64;
              }
            ];
          };
          defaultGateway = {
            address = "198.51.100.254";
            interface = "eth1";
          };
          defaultGateway6 = {
            address = "2001:db8::fe";
            interface = "eth1";
          };
          firewall = {
            enable = true;
            extraCommands = ''
              iptables -w -D OUTPUT -m owner --uid-owner librechat-code-sandbox -j librechat-sandbox-out 2>/dev/null || true
              iptables -w -F librechat-sandbox-out 2>/dev/null || true
              iptables -w -X librechat-sandbox-out 2>/dev/null || true
              iptables -w -N librechat-sandbox-out
              iptables -w -A librechat-sandbox-out -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
              iptables -w -A librechat-sandbox-out -d 127.0.0.53/32 -p udp --dport 53 -j ACCEPT
              iptables -w -A librechat-sandbox-out -d 127.0.0.53/32 -p tcp --dport 53 -j ACCEPT
              iptables -w -A librechat-sandbox-out -d 127.0.0.0/8 -j REJECT --reject-with icmp-port-unreachable
              iptables -w -A librechat-sandbox-out -d 10.0.0.0/8 -j REJECT --reject-with icmp-port-unreachable
              iptables -w -A librechat-sandbox-out -d 172.16.0.0/12 -j REJECT --reject-with icmp-port-unreachable
              iptables -w -A librechat-sandbox-out -d 192.168.0.0/16 -j REJECT --reject-with icmp-port-unreachable
              iptables -w -A librechat-sandbox-out -d 100.64.0.0/10 -j REJECT --reject-with icmp-port-unreachable
              iptables -w -A librechat-sandbox-out -d 169.254.0.0/16 -j REJECT --reject-with icmp-port-unreachable
              iptables -w -A librechat-sandbox-out -j RETURN
              iptables -w -I OUTPUT 1 -m owner --uid-owner librechat-code-sandbox -j librechat-sandbox-out

              ip6tables -w -D OUTPUT -m owner --uid-owner librechat-code-sandbox -j librechat-sandbox-out 2>/dev/null || true
              ip6tables -w -F librechat-sandbox-out 2>/dev/null || true
              ip6tables -w -X librechat-sandbox-out 2>/dev/null || true
              ip6tables -w -N librechat-sandbox-out
              ip6tables -w -A librechat-sandbox-out -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
              ip6tables -w -A librechat-sandbox-out -d ::1/128 -p tcp -j REJECT --reject-with tcp-reset
              ip6tables -w -A librechat-sandbox-out -d ::1/128 -j REJECT --reject-with icmp6-port-unreachable
              ip6tables -w -A librechat-sandbox-out -d fc00::/7 -p tcp -j REJECT --reject-with tcp-reset
              ip6tables -w -A librechat-sandbox-out -d fc00::/7 -j REJECT --reject-with icmp6-port-unreachable
              ip6tables -w -A librechat-sandbox-out -d fe80::/10 -p tcp -j REJECT --reject-with tcp-reset
              ip6tables -w -A librechat-sandbox-out -d fe80::/10 -j REJECT --reject-with icmp6-port-unreachable
              ip6tables -w -A librechat-sandbox-out -j RETURN
              ip6tables -w -I OUTPUT 1 -m owner --uid-owner librechat-code-sandbox -j librechat-sandbox-out
            '';
            extraStopCommands = ''
              iptables -w -D OUTPUT -m owner --uid-owner librechat-code-sandbox -j librechat-sandbox-out 2>/dev/null || true
              iptables -w -F librechat-sandbox-out 2>/dev/null || true
              iptables -w -X librechat-sandbox-out 2>/dev/null || true
              ip6tables -w -D OUTPUT -m owner --uid-owner librechat-code-sandbox -j librechat-sandbox-out 2>/dev/null || true
              ip6tables -w -F librechat-sandbox-out 2>/dev/null || true
              ip6tables -w -X librechat-sandbox-out 2>/dev/null || true
            '';
          };
        };

        users.users.librechat-code-sandbox = {
          isSystemUser = true;
          group = "librechat-code-sandbox";
          home = "/var/lib/librechat-code-sandbox";
        };
        users.groups.librechat-code-sandbox = { };

        # Ensure hostOnlyMarker is present in the VM's /nix/store outside sandboxClosure.
        environment.etc."librechat-host-only-marker".source = hostOnlyMarker;

        systemd.tmpfiles.rules = [
          "d /run/test-secrets 0700 root root -"
          "f /run/test-secrets/GH_TOKEN 0400 root root - ghp_vm_test_token"
          "f /run/test-secrets/CLOUDFLARE_ACCOUNT_ID 0400 root root - cf_vm_test_account"
          "f /run/test-secrets/CLOUDFLARE_API_TOKEN 0400 root root - cf_vm_test_token"
        ];

        systemd.services.host-probe-listener = {
          description = "Host-local loopback and abstract socket test listener";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${hostProbeListener}";
          };
        };

        systemd.services.librechat-codeapi-keygen = {
          description = "Generate Ed25519 JWT signing keys for LibreChat Code Interpreter";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root";
            Group = "root";
            StateDirectory = "librechat-codeapi-keys";
            StateDirectoryMode = "0755";
            ExecStart = lib.getExe librechatCodeApiKeygen;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
          };
        };

        systemd.services.librechat-code-sandbox = {
          description = "Local Code Interpreter sandbox service for LibreChat";
          after = [
            "network.target"
            "librechat-codeapi-keygen.service"
            "systemd-tmpfiles-setup.service"
          ];
          requires = [ "librechat-codeapi-keygen.service" ];
          wantedBy = [ "multi-user.target" ];
          path = sandboxPathPackages;
          environment = {
            BWRAP_BIN = "${lib.getExe pkgs.bubblewrap}";
            CODEAPI_JWT_AUDIENCE = "codeapi";
            CODEAPI_JWT_ISSUER = "librechat";
            CODEAPI_JWT_PUBLIC_KEY_FILE = "/var/lib/librechat-codeapi-keys/public.pem";
            HOST = "127.0.0.1";
            PASTA_BIN = "${lib.getExe' pkgs.passt "pasta"}";
            PORT = "3082";
            REQUESTS_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            SANDBOX_ADMIN_GIT_CONFIG = "${sandboxAdminGitConfig}";
            SANDBOX_CACHE_TTL_DAYS = "14";
            SANDBOX_CLEANUP_INTERVAL_SEC = "21600";
            SANDBOX_ETC_DIR = "${sandboxEtc}";
            SANDBOX_STORAGE_TTL_DAYS = "30";
            SANDBOX_STORE_PATHS_FILE = "${sandboxClosure}/store-paths";
            SANDBOX_WORKSPACE_TTL_DAYS = "7";
            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            STATE_DIR = "/var/lib/librechat-code-sandbox";
          };
          serviceConfig = {
            Type = "simple";
            ExecStart = "${lib.getExe serverPython} ${librechatCodeSandbox}/libexec/code-sandbox.py";
            Restart = "always";
            RestartSec = 5;
            User = "librechat-code-sandbox";
            Group = "librechat-code-sandbox";
            LoadCredential = [
              "GH_TOKEN:/run/test-secrets/GH_TOKEN"
              "CLOUDFLARE_ACCOUNT_ID:/run/test-secrets/CLOUDFLARE_ACCOUNT_ID"
              "CLOUDFLARE_API_TOKEN:/run/test-secrets/CLOUDFLARE_API_TOKEN"
            ];
            StateDirectory = "librechat-code-sandbox";
            StateDirectoryMode = "0700";
            TemporaryFileSystem = "/mnt:mode=0755";
            MemoryHigh = "6G";
            MemoryMax = "8G";
            CPUQuota = "400%";
            TasksMax = 512;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectControlGroups = true;
            ProtectKernelLogs = false;
            ProtectKernelModules = true;
            ProtectKernelTunables = false;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
              "AF_UNIX"
            ];
          };
        };
      };
  };

  testScript = ''
    start_all()
    remote.wait_for_unit("remote-http.service")
    remote.wait_for_open_port(8080)

    sandbox.wait_for_unit("librechat-codeapi-keygen.service")
    sandbox.wait_for_unit("host-probe-listener.service")
    sandbox.wait_for_open_port(18080)
    sandbox.wait_for_unit("librechat-code-sandbox.service")
    sandbox.wait_for_open_port(3082)

    # Confirm the host itself can reach remote before testing through pasta.
    sandbox.succeed("curl -fsS http://198.51.100.2:8080/ | grep -qx 'remote-egress-ok'")

    out = sandbox.succeed("${lib.getExe serverPython} ${sandboxVerifier}")
    assert "ALL_VM_SANDBOX_CHECKS_PASSED" in out, out
  '';
}
