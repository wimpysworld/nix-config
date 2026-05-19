# Fence Agent Policy

Fence is the policy boundary for Claude Code, OpenCode, and Pi when the fenced
aliases are used:

```console
claude-fenced
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
entry point. `opencode-fenced` runs the normal OpenCode TUI entry point with
`OPENCODE_PERMISSION='{"*":"allow"}'` in the environment, so it loads the same
configuration path as plain `opencode` while leaving Fence as the permission
boundary. `pi-fenced` runs the standard `pi` wrapper under Fence.

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

Device handling is pinned to Fence's `minimal` mode for deterministic Linux
sandbox behaviour.

Git commits are allowed, but `.git/hooks` and GitHub workflow files remain
protected. Fence has no approval or ask mode. Commands are allowed or denied.

The GitHub CLI needs `~/.config/gh/hosts.yml` at startup, so that file is not
read-denied. Fence allows `gh auth token` because Claude Code calls it, but
still blocks `gh auth status`, auth mutation, and the broad `gh api` escape
hatch. It cannot expose the `gh` credential only to the `gh` process.

`runtimeExecPolicy = "argv"` is required on Linux so Fence can inspect child
process `execve` arguments, rather than only masking executable paths.

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
fence -m --fence-log-file /tmp/fence-pi.log pi
```
