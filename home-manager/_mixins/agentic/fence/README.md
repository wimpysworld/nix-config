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

The wrappers use `fence -- <agent>` so any following flags are passed to the
agent rather than parsed as Fence flags. `claude-fenced` captures the terminal
width in `CCSTATUSLINE_WIDTH` before entering Fence, then runs Claude with
`--dangerously-skip-permissions`; Fence is the permission boundary for that
entry point. `codex-fenced` runs Codex with
`--dangerously-bypass-approvals-and-sandbox`, leaving Fence as the only sandbox
and command boundary for that entry point. `opencode-fenced` runs the normal
OpenCode TUI entry point with `OPENCODE_PERMISSION='{"*":"allow"}'` in the
environment, so it loads the same configuration path as plain `opencode` while
leaving Fence as the permission boundary. `pi-fenced` runs the standard `pi`
wrapper under Fence.

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

The Home Manager mixin builds Fence from the `llm-agents` flake input with a
single local override in [`package.nix`](./package.nix). The override rewrites
`linuxArgvExecMaxArgs` in `internal/sandbox/runtime_exec_argv_linux.go` to
`4096`, raising the per-process argv vector cap that Fence's Linux argv
runtime-exec policy will inspect. The upstream default is too low for
long-running native-toolchain builds (C, C++, Go, Rust), whose compile and
link invocations exceed Fence's argv cap and would otherwise be rejected
before the policy could decide; raising it lets those builds complete under
the policy.

The launch directory is writable through Fence's `"."` path rule. This matters
on Linux because Fence may otherwise re-bind the current project read-only while
reconstructing `/home` across mount boundaries.

Device handling is pinned to Fence's `minimal` mode for deterministic Linux
sandbox behaviour.

Command runtime enforcement uses Fence's `argv` mode on Linux. This lets Fence
inspect descendant process arguments, so multi-token denies such as `git push`,
`just switch-home`, `nix store delete`, and `nh home switch` remain enforced
after agent startup.

Some coreutils-backed denies are listed in
`acceptSharedBinaryCannotRuntimeDeny`. They remain preflight-denied, but are not
runtime-masked because Nixpkgs coreutils is a multicall binary and masking it
also masks essentials such as `env`.

Git commits and workflow edits are allowed. Fence has no approval or ask mode.
Commands are allowed or denied.

Filesystem policy is intentionally permissive for autonomous development and is
kept close to Fence's upstream coding-agent policy. Reads use Fence's normal
default-readable paths with extra NixOS profile and `/nix` allowances so
Landlock can execute Nix-store binaries and the sandbox can resolve Home Manager
profile shims. Secret paths remain read-denied. Writes are allowed to the launch
directory, common agent state, package caches, XDG config/data/state paths, and
`/tmp`.

SOPS material is denied across both the Home Manager and NixOS sides of this
flake: the user age key under `~/.config/sops/`, and the host age key under
`/var/lib/private/sops/`. Runtime mounts at `/run/secrets` and `/run/secrets.d`
are protected via on-disk file permissions. The user-facing sops-nix render
directory at `~/.config/sops-nix` is intentionally read-allowed so API keys are
exposed inside the sandbox.

The GitHub CLI needs `~/.config/gh/hosts.yml` at startup, so that file is not
read-denied. Fence allows `gh auth token` because Claude Code calls it, but
still blocks `gh auth status`, auth mutation, and the broad `gh api` escape
hatch. It cannot expose the `gh` credential only to the `gh` process.

Project-level `fence.jsonc` files should extend the user policy:

```json
{
  "extends": "@base",
  "filesystem": {
    "allowWrite": ["."]
  }
}
```

Useful validation commands:

```console
fence config show
fence config show --settings ~/.config/fence/fence.jsonc
fence --list-templates
fence --linux-features
fence -m --fence-log-file /tmp/fence-claude.log claude
fence -m --fence-log-file /tmp/fence-codex.log codex
fence -m --fence-log-file /tmp/fence-pi.log pi
```
