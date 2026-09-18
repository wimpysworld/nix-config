# Moltis projection

The assistants consumer projects agents, skills, and global instructions into `~/.moltis` for the Moltis client (tag 20260913.02). The gate is `moltisEnabled` in `../assistants/default.nix`, which matches the host gate in `mcp/default.nix`: user `martin`, Linux host, host tag `moltis` (skrye). The owned-files deployer tracks `~/.moltis` as an ownership root so its sops-rendered secret skills and managed links deploy there.

## Projection surfaces

| Destination                  | Source                                                     | Notes                                                                                                     |
| ---------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `~/.moltis/agents/<name>.md` | `agents/<name>/prompt.md` + `compose.readHeader`           | One file per coding agent, file by file. Moltis writes runtime workspaces into `~/.moltis/agents/`.        |
| `~/.moltis/skills/<name>/SKILL.md` | `compose.composeSkillsFor "moltis"`, allowlisted commands | Skill directories with `SKILL.md`; Moltis discovers skills one level deep and never writes inside a personal skill. |
| `~/.moltis/AGENTS.md`        | `instructions/global.md` + `compose.houseStyleBody`        | Plain Markdown, no frontmatter.                                                                            |

Agent frontmatter is `name` and `theme`; Moltis has no `description` field, so `theme` carries the agent description (Moltis `AgentFrontmatter`, `crates/config/src/agent_defs.rs`). The body becomes the preset's `system_prompt_suffix`.

Skill symlinks are safe because the skills manifest and registry installs live beside, not inside, the skills directory: `skills-manifest.json` sits at `~/.moltis/skills-manifest.json` (`crates/skills/src/manifest.rs`) and registry installs go to `~/.moltis/installed-skills/`, so nothing writes inside a personal `skills/<name>/` directory. Command-derived skills deploy as regular text files at `~/.moltis/skills/<name>/SKILL.md` rather than symlinks; their bodies are public command markdown.

## Command allowlist

Moltis has no slash-command surface. Its importer models a command as a skill (`create_skill_from_command`, `crates/import-core/src/skills.rs`), so selected commands deploy as skills under `~/.moltis/skills/`. An entry qualifies only when its `command.toml` proves `caller-context = true` and its body assumes no native platform tooling. The allowlist (`moltisCommandAllowlist` in `../assistants/default.nix`):

- `ack` - acknowledge feedback, conversational
- `ahem` - correct the last response, conversational
- `ask` - answer a question in the caller's context
- `call` - name a called agent, context-only
- `clarify-plan` - question a plan draft, conversational
- `gist` - rewrite the previous response concisely
- `handover-fresh` - handover to a fresh session, context-only
- `oi` - draw attention to the current work, conversational
- `ready` - session priming prompt, context-only

Each command runs in the caller's context, so no dispatch wrapper is needed, and Moltis provides no native tooling for the body to lean on.

## Not mapped

- **Secret commands**: `draft-self-review`, `gather-review-data`, `review-open-source-attestation`. Their bodies are sops-encrypted (`command.sops`) and never enter the Nix store, so they cannot be rendered as skills.
- **Dispatch-bound commands**: any command with `[compose] agent` set and `caller-context` unset (`agent = "..."` without `caller-context = true`, for example `draft-*`, `create-*`, `post-*`, `review-*`, `work-order-*`, `make-commit`, `make-pr`). Their bodies assume native Task, Agent, or `spawn_agent` tooling that Moltis does not project.
- **Desktop and CI commands**: commands that assume an interactive desktop or CI context, for example `babysit-pr`, `finish-pr`, `address-code-review`, `implement-task`, and `implement-plan`.

## Preset naming rule

Never name a projected Moltis agent preset `coordinator`, `auxiliary`, `compression`, or `review`. These collide with Moltis built-in presets and the WW-273 TOML lanes, and preset definitions merge over built-ins at load.

## Verification

After `just switch-home` on the moltis-tagged host, agents and skills appear in the Moltis UI.
