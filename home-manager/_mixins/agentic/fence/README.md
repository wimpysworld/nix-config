# Fence agent policy

Fence is a permissive accident guard for Claude Code, Codex, OpenCode, and Pi.
It reduces accidental damage when the fenced aliases are used, but it does not
contain a hostile or compromised agent:

```console
claude-fenced
codex-fenced
opencode-fenced
pi-fenced
```

The default user policy is managed by Home Manager at
`~/.config/fence/fence.jsonc`.

## Security model

Fence blocks selected commands and secret paths, isolates some temporary state,
and limits device access. The policy intentionally gives agents enough host
access for autonomous development:

| Access | Intentional scope |
| --- | --- |
| Filesystem reads | The filesystem root is readable, except for explicit `denyRead` masks and normal Unix permissions. |
| Network | Outbound domains, local outbound connections, and local listeners are unrestricted. |
| MCP secrets | The process receives required MCP API keys through its inherited environment and can read required client credentials and state. |
| Herdr | The Herdr control socket is writable, so agents can report their identity and state. |
| Temporary files | All fenced agents share a host directory through `TMPDIR`, at `~/.cache/fence-share`. |
| Writes | The launch directory, the main workspace trees, agent state, and broad XDG cache, data, and state trees are writable. Selected XDG configuration trees are also writable. |

These grants let an agent send readable data over the network, use authorised
credentials and services, and change writable host state. Use Fence to catch
mistakes, not as a security boundary against hostile code or prompt injection.

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
`--dangerously-skip-permissions`. Fence supplies the remaining local accident
guards for that entry point. `codex-fenced` runs Codex with
`--dangerously-bypass-approvals-and-sandbox`, leaving Fence as the only sandbox
and command filter for that entry point. This sandbox is still an accident
guard, not hostile-agent containment. `opencode-fenced` runs the normal OpenCode
TUI entry point with broad tool permission, while `webfetch` and `websearch`
remain denied so web access uses the Exa MCP server. It loads the same
configuration path as plain `opencode` while leaving Fence as the local accident
guard. `pi-fenced` runs the standard `pi` wrapper under Fence.

On Wayland, the fenced wrappers create a private per-launch runtime directory
with a symlink to the host Wayland socket for clipboard access. They expose
that temporary directory and the socket path to Fence, pass `XDG_RUNTIME_DIR`
and `WAYLAND_DISPLAY` to the fenced agent, and leave `/run/user/$UID` unexposed
as a directory. This is deliberately narrower than binding the host runtime
wholesale. Image paste needs the compositor socket, and the session bus is not
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

Command runtime enforcement uses `runtimeExecPolicy = "path"`. This permits
multithreaded tools such as Nix and Go to execute child processes. Single-token
executable denies remain runtime-enforced. Multi-token denies such as `git
config`, `just switch-home`, `nix store delete`, `nh home switch`, and `gitsign
initialize` are initial preflight checks. Fence applies them only when the
matching command is the initial fenced command.

The `nix-collect-garbage` deny and some coreutils-backed denies are listed in
`acceptSharedBinaryCannotRuntimeDeny`. Fence checks them only when they are the
initial fenced command. It does not runtime-mask them because Determinate Nix
uses one binary for `nix` and its legacy commands, while Nixpkgs coreutils uses
one binary for tools such as `env`. Masking either shared binary blocks required
development commands.

Git commits and workflow edits are allowed. Fence has no approval or ask mode.
Commands are allowed or denied.

## Local Git configuration is read-only

Fence bind-mounts `<repo>/.git/config` and `<repo>/.git/hooks` read-only for the
repository the agent launches in. Fence does this itself. It is not part of this
policy, `filesystem.denyWrite` is empty, and Fence exposes no switch for it. The
`allowGitConfig` option is unrelated: it controls read access to the user's own
`~/.gitconfig`.

Confirm it with `findmnt`, from inside a fenced agent:

```console
findmnt -rno TARGET,OPTIONS | grep '\.git'
```

Every local Git configuration write therefore fails:

```console
$ git config --local fence.probe 1
error: could not write config file .git/config: Device or resource busy
```

The error is `EBUSY`, not a permission error. Git writes `config.lock` and then
renames it over `config`, and the kernel refuses a rename onto a mount point.
`fence --expose-host-path-rw` does not help, because a read-write bind is still
a mount point. The same applies to any tool that rewrites the file, so a fenced
agent cannot repoint a remote, a credential helper, or `core.hooksPath` this
way.

What an agent loses is branch tracking. `git push -u origin <branch>` pushes the
branch and then fails on the upstream write. Nothing else about pushing is
affected: `git push` is not denied, and pushing as the user is intended.

[`git.nix`](./git.nix) sets `push.default = current` for fenced agents so this
costs nothing in practice. A bare `git push` sends the current branch to the
branch of the same name on the remote and creates it when missing, without an
upstream and without a local write. This matters because the base configuration
uses `push.default = matching`, under which a bare push of a branch the remote
does not have yet pushes nothing and still exits zero.

Guidance for agent prompts:

- Push with an explicit refspec, `git push origin <branch>`, and drop `-u`.
- Read the remote head as `origin/<branch>`, not `<branch>@{u}`.
- Verify a push by comparing `git rev-parse HEAD` with `git rev-parse FETCH_HEAD`
  after `git fetch origin <branch>`.
- Treat the read-only mount as a fact to report, never as a safety control to
  refuse work over.

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

The filesystem root is read-granted. Landlock rules are additive and Fence
grants subtrees, never `/` itself, so `open("/")` fails with `EACCES` in the
default policy. Nix opens `/` whenever evaluation leaves pure flake mode:
`nix eval --impure`, `nix-instantiate`, `nix shell`, `nix run`, and
registry-resolved installables such as `nixpkgs#hello` all fail with
`error: opening file "/": Permission denied` without the grant, which also
breaks `just eval`. The `"/"` entry in `allowRead` fixes this. It does not
expose secret material: `denyRead` paths are enforced by Fence's mount
masks, not by Landlock, and the Landlock read layer already covered the
home directory, `/tmp`, and every system path. What the grant adds is the
`/` and `/home` directory inodes plus paths that remain guarded by ordinary
file permissions, such as `/root`. The narrower entries stay listed so the
policy still stands on its own if the root grant is ever removed.

SOPS material is denied across both the Home Manager and NixOS sides of this
flake: the user age key under `~/.config/sops/`, and the host age key under
`/var/lib/private/sops/`. Runtime mounts at `/run/secrets` and `/run/secrets.d`
are protected via on-disk file permissions. The user-facing sops-nix render
directory at `~/.config/sops-nix` is intentionally read-allowed so API keys are
exposed inside the sandbox.

## Never name a path under `/run` in this policy

Fence rebuilds any mount boundary it has to cross. For each `allowExecute`,
`allowRead`, or `allowWrite` path on a different device from `/`, it places a
`--tmpfs` at the first mount boundary, recreates the intermediate directories,
and then binds only the named target. `/run` is its own tmpfs on NixOS, so a
single policy entry anywhere under `/run` blanks the entire tree and leaves
behind only what the policy names.

That is not a theoretical risk. Adding `/run/user/*/fence-share` to `allowWrite`
removed `/run/current-system/sw/bin` from the sandbox, so `bash`, `sha1sum`, and
every other system binary stopped resolving, and it removed
`/run/user/$UID/secrets.d`, so every sops-nix secret became unreadable. Three
unrelated-looking faults followed: a herdr hook that could not find `bash`, a
project devShell that would not load because nix-direnv could not hash its cache
key, and `slack-post` reporting that its token file was missing.

Keep shared paths on the same device as `/`. The agent share directory is
`~/.cache/fence-share` for this reason. The Wayland bridge and the Chromium
wrapper both use `/tmp`, which the policy already tmpfs-mounts on purpose.

Commits in work repositories under `~/Chainguard` are signed with Sigstore
through gitsign. The `gitsign-credential-cache` daemon runs on the host. On
Linux, its socket is at `~/.cache/sigstore/gitsign/cache.sock` and the TUF root
is `~/.cache/sigstore/root`. On Darwin, the matching paths are
`~/Library/Caches/sigstore/gitsign/cache.sock` and
`~/Library/Caches/sigstore/root`. Fenced and unfenced gitsign share this
writable TUF state through `TUF_ROOT`. What crosses the socket is an ephemeral
signing key and a Fulcio certificate that expires after ten minutes, so no
long-lived secret enters the fence: no SSH key, no GPG key, and no Google ID
token. Signing is scoped by a
`gitdir:~/Chainguard/*/` include in the Git configuration, so it applies to the
nested work clones and nowhere else. The fenced wrappers point
`GIT_CONFIG_GLOBAL` at a Fence-owned global file. That file includes the real
global configuration, turns `commit.gpgSign` and `tag.gpgSign` off, then turns
them back on under the same `gitdir:~/Chainguard/*/` condition. Signing is off
by default because the base configuration signs with an SSH key that Fence
read-denies. Git evaluates the condition per repository, every time it runs, so
the launch directory does not matter, and neither does a later `cd`, `git -C`,
or `GIT_DIR`. An agent launched from a directory in no repository at all still
signs correctly once it reaches a work clone. A linked worktree of a work clone
checked out anywhere also signs with gitsign, because its Git directory lives
under the main clone. `~/Chainguard` itself is a personal repository and takes
the unsigned path, because the condition needs a path component between
Chainguard and the Git directory. `GIT_CONFIG_*` cannot express this: those
variables carry `command line:` origin, which outranks every configuration file
including a conditional include, so an injected `commit.gpgSign=false` would
win inside work clones too.
The Linux XDG cache grant covers the Sigstore cache. Darwin grants only the
Sigstore cache directory and its descendants.
`gitsign initialize` is denied because it rewrites that trust root and changes
what later local verification accepts. The multi-token enforcement limit above
applies to that deny.

The trade-off is real. An agent that reaches the socket can sign as the work
identity for a rolling ten-minute window, and every Sigstore signature is
recorded in a public transparency log that is permanent and cannot be removed.

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
family-wide deny, with read-only subcommands and flags carved out so
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
read flag, when scripting against Fence. Every write form (bare positional
assignment, `--add`, `--unset`, `--replace-all`, `--rename-section`,
`--remove-section`, `--edit`, and the modern `set`/`unset`/`rename-section`/
`remove-section` subcommands) is denied. Raw `gh api` is the escape hatch
and stays denied in the Fence command policy. The `gh` command is an
environment-aware dispatcher. Inside Fence, it sends every raw API request
to `gh-api-safe` and applies the GitHub deny families before it starts the
private `gh` backend. It also blocks unknown top-level names, which prevents
configured aliases and unmanaged extensions from bypassing those rules. The
managed `dash`, `enhance`, `markdown-preview`, and `notify` extensions remain
available. `gh agent-task` permits `list` and `view`, while `create` stays
blocked. `gh skill` permits `list`, `preview`, and `search`, while its change
commands stay blocked. `gh copilot` stays blocked because it downloads or
starts another agent. `gh discussion` remains available because its normal
changes match the permitted issue and comment workflows. Outside Fence, it
starts the backend without policy checks. The
Fence policy keeps literal allowances for `gh api rate_limit`,
`gh api meta`, and `gh api octocat` so those initial commands can reach the
dispatcher. Other raw reads must start inside the fenced agent. One write
path is allowed by name: `gh-review-reply`
posts a threaded reply to a pull request review comment and reaches only
`POST /repos/{owner}/{repo}/pulls/{n}/comments/{id}/replies`. It builds
that path itself from validated arguments, refuses every endpoint,
method, and field flag, and exits 64 on a policy violation. The
family-wide `gh api` deny is unaffected and `gh-api-safe` stays
read-only. The wider `gh` policy follows the same family-wide deny
plus longer-prefix allow pattern: list-like discovery reads under
`gh extension`, `gh release`, `gh project`, `gh codespace`, `gh label`,
`gh secret`, `gh variable`, `gh gpg-key`, `gh ssh-key`, and
`gh repo deploy-key` are carved out above their respective family-wide
denies. `gh project` also carves out `item-add` and `item-edit`, the two
item writes the task commands use to place an issue on a project and set
one field on it. `gh config` is the sole exception and is denied wholesale
because `gh config get oauth_token --host github.com` can disclose the
OAuth token stored in `~/.config/gh/hosts.yml`. The Fence source of truth is
[`default.nix`](./default.nix). The dispatcher mirrors its GitHub rules in
[`gh-dispatch.sh`](../../development/github/gh-dispatch.sh), because the
Fence configuration and the shell wrapper use different policy formats.

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
