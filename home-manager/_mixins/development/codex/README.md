# Codex

[Codex CLI](https://github.com/openai/codex) (codex-rs 0.118.0) configured declaratively via Home Manager. Skills, agents, and security policy are all generated from Nix; runtime state stays mutable.

```bash
codex                  # start interactive TUI
/skills                # list all skills
$skill-name            # invoke a skill by name in the composer
```

---

## Configuration

All settings live in `~/.codex/config.toml`. The file is written as a real file during Home Manager activation, not a symlink, because codex edits it in-place at runtime to persist trust decisions. A symlinked file points into the read-only Nix store; codex's writes fail silently and every session re-prompts for trust.

The activation script uses `[ ! -f ]` to guard the copy: subsequent `home-manager switch` runs preserve any runtime edits codex has appended (extra project trust entries, model preferences).

---

## Skills

Skills inject instructions into the active conversation. Type `$` in the composer to open the picker, or type `$skill-name` directly.

Skills come from two sources:

- **Shared skills** - `assistants/skills/*/SKILL.md` - reference knowledge usable across all tools (GitHub CLI, code security, LLM security, Semgrep, writing guides, agent registry)
- **Command skills** - one skill per agent command, with the agent's full persona embedded directly in the skill body

Skills are also written as real files via activation script. The codex-rs scanner calls `entry.file_type()` without following symlinks on Linux, so symlinked `SKILL.md` files are silently skipped.

### Command skills

Each agent command becomes a skill named `<agent>-<command>`. The skill body embeds the agent's `prompt.md` followed by the command's `prompt.md` under a `## Task` heading. This is necessary because codex-rs has no runtime agent resolution: there is no mechanism to say "run this as Garfield". The persona must travel with the skill.

```
$garfield-create-conventional-commit   # Garfield's full persona + commit task
$donatello-implement-code              # Donatello's full persona + implementation task
$penfold-deep-research                 # Penfold's full persona + research task
```

Standalone commands (not scoped to an agent) become skills without a prefix:

```
$ready        # step-back priming prompt
$onboard      # project onboarding instructions
$orientate    # re-orient mid-session
$collaborate  # set collaboration expectations
$botsnack     # positive reinforcement
```

---

## Agents

Agent `.toml` files in `~/.codex/agents/` define roles the model can apply when spawning sub-agent threads during task execution. They extend the built-in roles (`default`, `explorer`, `worker`) with the full team of specialist agents.

The same real-file constraint applies: `collect_agent_role_files_recursive` uses `is_file()` which returns false for symlinks on Linux.

Agent roles are not user-selectable from the TUI. `/agent` shows active live threads, not a persona picker. The roles become available to the model's `spawn_agent` tool calls.

---

## Security

### Sandbox

`sandbox_mode = "workspace-write"` confines filesystem access to the current project plus `/tmp`. SSH keys, GPG keys, cloud credentials, and shell history outside the sandbox are structurally inaccessible.

The sandbox extends to four personal development roots:

```
~/Chainguard   ~/Development   ~/Volatile   ~/Zero
```

Outbound network access from within the sandbox is disabled. MCP servers handle all external network requests through their own processes.

### Approval policy

`approval_policy = "untrusted"` auto-approves the built-in trusted command set (read-only shell tools, `git` queries, file reads) without prompting. Everything else requires explicit approval.

### Forbidden commands

`~/.codex/rules/default.rules` adds unconditional `forbidden` rules on top of the approval policy. These commands are blocked regardless of approval - they cannot be allowed interactively. Categories:

| Category | Commands |
|----------|----------|
| Privilege escalation | `sudo` |
| Disk operations | `dd`, `fdisk`, `parted`, `mkswap`, `mount`, `umount` |
| Kernel modification | `sysctl`, `modprobe`, `insmod`, `rmmod` |
| Boot / firmware | `grub-install`, `efibootmgr` |
| Subshell bypasses | `bash -c`, `sh -c`, `python -c`, `node -e`, `perl -e`, etc. |
| System power | `systemctl poweroff/reboot/halt/suspend/hibernate` |
| Destructive git | `git push --force`, `git reset --hard`, `git clean`, `git filter-branch` |
| Mass deletion | `docker system prune`, `docker volume prune` |
| Secure deletion | `shred`, `wipe`, `srm`, `truncate` |
| Nix GC | `nix-collect-garbage` |

### Environment

`shell_environment_policy` strips credential variables from every subprocess environment. The `"core"` baseline keeps `PATH`, `HOME`, and essential variables; the exclude list removes `*_API_KEY`, `*_SECRET`, `*_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN`, and cloud provider variables.

### Project trust

The `[projects]` block pre-seeds trust for the four development roots. Without this, codex prompts "Do you trust this directory?" on every launch. The trust check resolves the git repository root for the current working directory; a single entry for `~/Zero` covers all subdirectories including `~/Zero/nix-config`.

---

## File layout

```
codex/
└── default.nix          # config.toml, exec policy rules, MCP servers

assistants/
├── agents/<name>/
│   ├── prompt.md        # agent persona and constraints
│   ├── description.txt  # one-line description (used in agent .toml)
│   └── commands/<cmd>/
│       ├── prompt.md    # command task instructions
│       └── description.txt
├── commands/<name>/     # standalone commands (no agent scope)
│   ├── prompt.md
│   └── description.txt
├── skills/<name>/
│   └── SKILL.md         # shared reference skills
├── compose.nix          # content assembly functions
└── default.nix          # deployment to all platforms
```

Source for all agents, commands, and skills is in `assistants/`. The codex mixin reads from there and writes real files to `~/.codex/` during activation. The assistants README covers the full cross-platform picture.
