# Fence Agent Policy

Fence is the policy boundary for Claude Code, Codex, OpenCode, and Pi when the
fenced aliases are used:

```console
claude-fenced
codex-fenced
opencode-fenced
pi-fenced
```

The default user policy is managed by Home Manager at
`~/.config/fence/fence.jsonc`.

The Fence mixin owns the shared policy and runtime dependencies. Each fenced
command is declared by the corresponding agent mixin so it appears only when
the standard agent entry point is also installed.

The wrappers use `fence -- direnv exec "$PWD" env <agent>` so project devShell
tools are available and any following flags are passed to the agent rather than
parsed as Fence flags. They also set `BASH_ENV` to load direnv for each
non-interactive Bash command. This activates the environment for the command's
working directory when an agent server starts elsewhere and later enters a
project. Direnv runs inside Fence, so project-controlled `.envrc` files never
execute outside the sandbox. `claude-fenced` runs Claude with
`--dangerously-skip-permissions`; Fence is the permission boundary for that
entry point. `codex-fenced` runs Codex with
`--dangerously-bypass-approvals-and-sandbox`, leaving Fence as the only sandbox
and command boundary for that entry point. `opencode-fenced` runs the normal
OpenCode TUI entry point with `OPENCODE_PERMISSION='{"*":"allow"}'` in the
environment, so it loads the same configuration path as plain `opencode` while
leaving Fence as the permission boundary. `pi-fenced` runs the standard `pi`
wrapper under Fence.

On Wayland, the fenced wrappers create a private per-launch runtime directory
with a symlink to the host Wayland socket for clipboard access. They expose
that temporary directory and the socket path to Fence, pass `XDG_RUNTIME_DIR`
and `WAYLAND_DISPLAY` to the fenced agent, and leave `/run/user/$UID` unexposed
as a directory. This is deliberately narrower than binding the host runtime
wholesale: image paste needs the compositor socket, and the session bus is not
exposed.

Fenced agents on non-server hosts also get a Chromium wrapper first on `PATH`.
The wrapper creates private writable browser state under
`/tmp/fence-chromium.*`, sets `HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`,
`XDG_DATA_HOME`, `XDG_STATE_HOME`, and `XDG_RUNTIME_DIR` for Chromium only, and
passes a private `--user-data-dir` when the caller has not set one. This keeps
Crashpad and profile writes out of the real home directory. The fenced
environment also sets `NYALA_BROWSER` and `CHROME_PATH` to that wrapper, so
Nyala and chromedp callers do not bypass it through host browser environment
variables. Server hosts do not install this bridge.

Chromium should use its user namespace sandbox inside Fence. The wrapper passes
`--disable-setuid-sandbox` because the Nix store cannot provide a working SUID
helper inside the sandbox. Do not use `--no-sandbox` as a normal setting. Keep
Fence's `ptrace` deny in place; Crashpad is disabled with
`--disable-crash-reporter` and `--disable-breakpad` so browser launch does not
need a ptrace grant.

For local Nyala debugging on hosts where Chromium user namespaces are blocked,
set `NYALA_DEBUG_CHROMIUM_NO_SANDBOX=1` before launching the fenced agent. That
adds `--no-sandbox` for Chromium only. This is a debug workaround, not a
deployment setting. Unset it after use. It does not grant ptrace, bind host
`/proc`, expose host `/dev/shm`, or change server policy.

Claude Code's user settings include
`skipDangerousModePermissionPrompt = true` so `claude-fenced` starts
directly instead of stopping at the bypass-mode responsibility prompt. Fence
also exposes the Nix-managed ccstatusline settings directory read-only so the
custom status line renders inside the sandbox. Fence does not configure Claude
Code's command or filesystem permission policy.

The policy is standalone rather than extending Fence's `code` templates. This
keeps the generated config reviewable: full outbound network access is expressed
as `allowedDomains = ["*"]`, with no inherited domain deny-list. Filesystem and
command policy still apply.

The Home Manager mixin uses the Fence package from the `llm-agents` flake
input with a local shared-binary probe for `nix`. Fence only honours
`acceptSharedBinaryCannotRuntimeDeny` after it detects a collision with one of
its critical command names. The probe lets Fence detect that Determinate Nix's
legacy commands resolve to the same binary as `nix`.

The launch directory is writable through Fence's `"."` path rule. This matters
on Linux because Fence may otherwise re-bind the current project read-only while
reconstructing `/home` across mount boundaries.

Device handling is pinned to Fence's `minimal` mode for deterministic Linux
sandbox behaviour.

Command runtime enforcement uses Fence's `path` mode. This permits
multithreaded tools such as Nix and Go to execute child processes. Single-token
executable denies remain runtime-enforced. Multi-token denies such as `git
push`, `just switch-home`, `nix store delete`, and `nh home switch` remain
preflight-enforced only when they are the initial fenced command. Fence cannot
enforce them against commands spawned by an agent in this mode.

The `nix-collect-garbage` deny and some coreutils-backed denies are listed in
`acceptSharedBinaryCannotRuntimeDeny`. Fence checks them only when they are the
initial fenced command. It does not runtime-mask them because Determinate Nix
uses one binary for `nix` and its legacy commands, while Nixpkgs coreutils uses
one binary for tools such as `env`. Masking either shared binary blocks required
development commands.

Git commits and workflow edits are allowed. Fence has no approval or ask mode.
Commands are allowed or denied.

Filesystem policy is intentionally permissive for autonomous development and is
kept close to Fence's upstream coding-agent policy. Reads use Fence's normal
default-readable paths with extra NixOS profile and `/nix` allowances so
Landlock can execute Nix-store binaries and the sandbox can resolve Home Manager
profile shims. `allowExecute` lists `/nix` as a single tree so Fence does not
replace the store with a private tmpfs and then bind only a few leaf paths. That
keeps staged Fence bootstrap binaries, `gh` wrapper shebangs, and their runtime
closures visible without weakening the raw `gh api` deny. Fence's staged
`/tmp/fence/bin/fence` self-exec path is not listed because Fence creates it
inside the Bubblewrap bootstrap; treating it as a host allowExecute path makes
Fence try to cross-mount an unstable `/tmp` path before the bootstrap bind
exists. Secret paths remain read-denied. Writes are allowed to the launch
directory, common agent state, package caches, XDG config/data/state paths, and
the private `/tmp` tmpfs. `/tmp` is allowed as a bare directory rather than a
glob so Landlock covers temp paths created after Fence starts.

SOPS material is denied across both the Home Manager and NixOS sides of this
flake: the user age key under `~/.config/sops/`, and the host age key under
`/var/lib/private/sops/`. Runtime mounts at `/run/secrets` and `/run/secrets.d`
are protected via on-disk file permissions. The user-facing sops-nix render
directory at `~/.config/sops-nix` is intentionally read-allowed so API keys are
exposed inside the sandbox.

The GitHub CLI needs `~/.config/gh/hosts.yml` at startup, so that file is not
read-denied. It cannot expose the `gh` credential only to the `gh` process.
Fence allows the `gh auth` subcommands so the agent can inspect its identity
and rotate credentials. `gh auth token` is also allowed because Claude Code
requires it, even though it prints the OAuth credential to stdout. `gh auth
setup-git` and `gh auth login --with-token` (both the bare flag and the
`--with-token=` forms) stay denied. `setup-git` would rewrite the Nix-managed
git configuration, and `--with-token` silently rebinds the active credential
from stdin or a file path. The git side of that closure is enforced directly:
`git config` is a
family-wide deny, with read-shaped subcommands and flags carved out so
inspection still works. The modern reads (`git config get`, `get-all`,
`get-regexp`, `get-urlmatch`, `list`) match on the first token after
`config`, so any destination flag (`--global`, `--system`, `--local`,
`--file`, `--worktree`, `--blob`) may trail the read token and the carve-out
still fires. The legacy flag reads (`--get`, `--get-all`, `--get-regexp`,
`--get-urlmatch`, `--get-color`, `--get-colorbool`, `--list`, `-l`) only
match when the read flag is the first token after `config`; placing a
destination flag before the read flag (e.g. `git config --global --get
user.email`) is not carved out and falls through to the family-wide deny.
Prefer the modern subcommand form, or put the destination flag after the
read flag, when scripting against Fence. Every write shape (bare positional
assignment, `--add`, `--unset`, `--replace-all`, `--rename-section`,
`--remove-section`, `--edit`, and the modern `set`/`unset`/`rename-section`/
`remove-section` subcommands) is denied. Raw `gh api` is the escape hatch
and stays denied; read-shaped requests go through the `gh-api-safe` wrapper,
with literal allowances only for `gh api rate_limit`, `gh api meta`, and
`gh api octocat`. The wider `gh` policy follows the same family-wide deny
plus longer-prefix allow pattern: list-like discovery reads under
`gh extension`, `gh release`, `gh project`, `gh codespace`, `gh label`,
`gh secret`, `gh variable`, `gh gpg-key`, `gh ssh-key`, and
`gh repo deploy-key` are carved out above their respective family-wide
denies. `gh config` is the sole exception and is denied wholesale
because `gh config get oauth_token --host github.com` can disclose the
OAuth token stored in `~/.config/gh/hosts.yml`. The source of truth is
[`default.nix`](./default.nix).

Project-level `fence.jsonc` files should extend the user policy:

```json
{
  "extends": "@base",
  "filesystem": {
    "allowWrite": ["."]
  }
}
```

## Per-launch logs

Every fenced wrapper sources [`logging.nix`](./logging.nix) alongside the
Wayland bridge helper. The helper sets `fence_log_agent` per wrapper
(`claude`, `codex`, `opencode`, `pi`), then writes a per-launch log path
into `fence_args` so each invocation runs as:

```console
fence -m --fence-log-file "$XDG_STATE_HOME/fence/<agent>-<timestamp>-<pid>.log" -- ...
```

`-m` (monitor) routes Fence's `[fence:http]`, `[fence:socks]`,
`[fence:logstream]` (macOS), and `[fence:ebpf]` (Linux, needs `CAP_BPF`)
prefixes through `fencelog`, which the flag then redirects off the agent's
stderr. Preflight `CommandBlockedError`/`SSHBlockedError` text is written
through cobra and stays on stderr, so the agent still sees denials in the
TUI. Per-launch filenames sidestep Fence's truncate-on-open behaviour for
`--fence-log-file`, so each session has its own audit trail. A
`<agent>-current.log` symlink in the same directory always points at the
latest file.

The log directory is mode `0700` and Fence opens log files mode `0600`.
A user-level systemd-tmpfiles rule under `fence/default.nix` ages files out
after 14 days. Logs can contain argv, blocked URLs, and filesystem paths,
so this window is deliberately short.

Use the `fence-log` helper to browse:

```console
fence-log claude            # page the current Claude log
fence-log codex tail        # tail -F the current Codex log
fence-log opencode list     # list historical OpenCode logs, newest first
fence-log pi path           # print the resolved current log path
fence-log --list-agents     # print the whitelist of agent names
```

Useful validation commands:

```console
fence config show
fence config show --settings ~/.config/fence/fence.jsonc
fence --list-templates
fence --linux-features
claude-fenced --help
fence-log claude
```

To validate Wayland clipboard visibility through the wrapper, run a fenced
agent from a Wayland session and check that image paste works. For a raw shell
probe, compare the current Fence behaviour with the wrapper bridge:

```console
fence fish -c 'wl-paste --list-types'
claude-fenced --help
```
