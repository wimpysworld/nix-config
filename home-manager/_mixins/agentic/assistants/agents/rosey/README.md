# Rosey

Onboarding and reference for Rosey, the prompt and skill specialist in this
repo. Read this before editing Rosey's prompt, her four writing skills, or any
of the command shims that point at them. It captures the research and doctrine
that shaped the current design so future edits stay coherent.

## 1. Purpose

Rosey crafts, refines, and maintains the artefacts that other agents are built
from: agent system prompts, agent skills, slash commands, and project
instruction files (`AGENTS.md`, `CLAUDE.md`, and friends). She is a specialist
sub-agent rather than a generalist; her own prompt stays small and pushes all
doctrine into four task-specific skills. The guiding rule is that every token
in any artefact she touches must earn its place. Tokens spent on persona,
restatement, hedging, or duplicated rules are tokens stolen from the user's
actual task.

## 2. Architecture

Rosey is one persona plus four writing skills plus a thin layer of command
shims. The persona stays short; the skills own the doctrine; the shims do
nothing but capture an argument and load the right skill.

```text
agents/rosey/
  prompt.md                 persona, routing, constraints (≤30 lines)
  commands/
    create-skill/           shim → write-skill (create flow)
    update-skill/           shim → write-skill (update flow)
    create-assistant/       shim → write-assistant (create flow)
    update-assistant/       shim → write-assistant (update flow)
    create-agents-md/       shim → write-agents-md (create flow)
    update-agents-md/       shim → write-agents-md (update/consolidate)
    create-command/         shim → write-command (create flow)
    update-command/         shim → write-command (update flow)

skills/
  write-skill/              SKILL.md doctrine for agent skills
  write-assistant/          SKILL.md doctrine for agent system prompts
  write-agents-md/          SKILL.md doctrine for project instruction files
  write-command/            SKILL.md doctrine for slash commands
```

### 2.1 Skill responsibilities

| Skill             | Owns                                                                                     | Loads when                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `write-skill`     | Agent Skills open spec, SKILL.md frontmatter, progressive disclosure, references layout  | User edits or creates a `SKILL.md`; mentions "skill", "skills", or names a skill path             |
| `write-assistant` | Agent system prompts, persona, capabilities, voice, output contracts, sub-agent triggers | User edits or creates an agent prompt, sub-agent, assistant, or persona artefact                  |
| `write-agents-md` | `AGENTS.md` open spec, `CLAUDE.md`, `.cursor/rules/*`, consolidation and migration       | User edits or creates project instructions, rules, project memory, or mentions any of those names |
| `write-command`   | Slash commands and prompt templates, shim shape, headers per provider, `$ARGUMENTS`      | User edits or creates a slash command, prompt template, or command shim                           |

Each skill is description-triggered. The trigger phrases live in the
`description` frontmatter field, not in the body, because the body only loads
after the description has already matched.

### 2.2 Shim, not monolith

Every Rosey command is a shim of four to six body lines. The shape is
identical across all eight commands except for the skill name and the verb:

```markdown
## <Verb> <Artefact>

Load the `write-<thing>` skill and run its **<create|update>** flow.

Target argument: $ARGUMENTS. If blank, ask for the target path or name.

Apply `write-<thing>` end-to-end. Do not duplicate that guidance here.
```

Shims win over monolithic command bodies for three reasons:

1. **Single source of truth.** Doctrine lives in one skill, not duplicated
   across create and update commands. The prior `create-skill` and
   `update-skill` pair shared roughly 70% of their bodies and had already
   drifted; collapsing the doctrine into `write-skill` removed the drift.
2. **Progressive disclosure.** The skill body loads on demand, not on every
   invocation. Command bodies sit in every turn's prefix once the
   conversation continues, so keeping them short keeps the active context
   small.
3. **Cache stability.** Identical shim shapes across all eight commands cache
   well because the prefix structure varies only by skill name. Stable
   prefixes are the primary lever for prompt caching on both Anthropic and
   OpenAI.

A command should be self-contained only when no doctrine is shared. The
moment a second sibling appears (a "create" and an "update", say), the shared
parts belong in a skill.

## 3. Design principles

These principles shape every Rosey artefact. They are the answer to "why is
this so terse?" and they are deliberately consistent across skill bodies,
agent prompts, and project instructions.

### 3.1 Every token earns its place

Terse prompts outperform verbose ones in compliance and cost. Community
evidence cited in the research shows roughly 5x fewer tokens and around 8%
higher compliance on terse variants. Anthropic's own agent-development skill
puts agent system prompts at 500-3,000 characters as the best band and
caps them at 10,000 characters. Rosey's targets sit inside that band:

| Artefact            | Target                                 | Hard cap                 |
| ------------------- | -------------------------------------- | ------------------------ |
| Agent system prompt | 400-700 words / 500-3,000 chars        | 10,000 chars             |
| Skill body          | 1,500-2,000 words                      | 500 lines                |
| Reference file      | ≤100 lines (TOC if longer)             | one level deep           |
| `AGENTS.md` root    | 50-200 lines                           | 32 KiB (Codex truncates) |
| Command shim body   | 4-6 lines                              | 10 lines                 |
| Standalone command  | 30-60 lines if it has an output format | 80 lines                 |
| `description.txt`   | ≤50 chars                              | 60 chars                 |
| `argument-hint`     | ≤25 chars                              | 30 chars                 |

The numbers are guidance, not religion. The "would removing this cause the
agent to make mistakes?" test from Anthropic's `CLAUDE.md` guidance is the
real arbiter. If the answer is no, cut it.

### 3.2 Imperatives over descriptions

"Use TypeScript strict mode for new files" beats "the project uses TypeScript".
"Load `write-skill` and apply it" beats "you should probably consider loading
`write-skill`". Imperatives are shorter, clearer, and produce better adherence.
First person ("I will") and hedged second person ("you should") both reduce
compliance.

### 3.3 No hedging, no filler, no aggressive caps

"IMPORTANT" and "YOU MUST" worked on older Claude models but Opus 4.5 and
Sonnet 4.6 over-trigger on aggressive language. Default to plain imperatives.
Cut "the fact that", "in order to", "it should be noted that", and the LLM
tells listed in `writing-clearly-and-concisely` (pivotal, crucial, seamless,
robust, leverage, foster, and the rest).

### 3.4 One default per decision

Offering many options invites the model to pick badly. Pick a default and
mention alternatives only when behaviour materially diverges. The same rule
applies to skill bodies and agent prompts.

### 3.5 Show, don't describe

Output formats belong in fenced templates, not prose. Examples are required
only for subjective or judgement work. Procedural agents and skills usually
do not need them; the imperative is enough.

### 3.6 Flag contradictions before editing

The GPT-5.1 prompting guide's headline practice. "Be concise" and "be
thorough" cannot both win. When updating an artefact, surface the conflict
first, pick a default, and edit surgically. Small explicit edits beat
redesigns.

### 3.7 Cache hygiene

Static instructions go first; volatile task data goes last. Avoid timestamps,
session IDs, dynamic routing snippets, or generated content in command bodies
or skill prefixes. Observed cache reads dominate writes, which validates
stable-prefix design but does not justify prompt bloat. Cached tokens still
consume context and, on OpenAI, still count against rate limits.

## 4. Portability principles

The repo targets four runtimes: Claude Code, OpenCode, Pi, and Codex.
Skill and command artefacts must work across all four; vendor extensions
are isolated to references and per-provider header files.

### 4.1 Portable frontmatter only

A SKILL.md frontmatter in this repo uses only the two fields from the open
spec at `agentskills.io`:

```yaml
---
name: <kebab-case, ≤64 chars, matches parent dir>
description: <≤1024 chars, third person, when-to-use, trigger-rich>
---
```

Vendor-specific fields (`when_to_use`, `allowed-tools`, `disable-model-invocation`,
`user-invocable`, `argument-hint`, `paths`, `model`, `effort`, `context`,
`agent`, `hooks`, `shell` from Claude Code; `agent` and `subtask` from
OpenCode; the Codex companion `agents/openai.yaml`) are documented in
`write-skill/references/portability.md` but kept out of the SKILL.md
frontmatter so the file loads cleanly on every runtime.

`AGENTS.md` uses **no** frontmatter at all; the open `agents.md` spec is
plain Markdown with any headings, and vendor parsers do not read YAML at the
top of an `AGENTS.md`. Cursor's `.cursor/rules/*.mdc` is the one exception,
and it lives in a separate file.

### 4.2 The "when to use lives in description" rule

The body of a skill loads only after the description has triggered. A
section titled "When to use" inside the body therefore cannot drive
selection; it is dead text by the time anyone reads it. All triggering
information (verbs, file paths, synonyms, edge cases) goes in the
description. The body assumes the trigger has already fired.

OpenAI's `skill-creator` and Anthropic's `skill-development` both stress
this; it is the highest-leverage habit for skill authors.

### 4.3 Descriptions are third person

Skill descriptions are written in the third person ("Use when…", "Covers…"),
not first or second. Anthropic flags first or second person in descriptions
as a viewpoint conflict when the description is injected into a system
prompt that already addresses the model as "you". Agent system prompts in
contrast are second-person imperative ("You are…", "Use X when Y"). The
voice differs by artefact; mixing them weakens adherence.

### 4.4 Argument substitution

`$1` is the first positional argument on Pi, OpenCode, and Codex. In Claude
Code's new merged skill-as-command format, `$N` is `$ARGUMENTS[N]` with
zero-based indexing, so `$0` is the first argument and `$1` is the second.
The portable choice for a single free-form argument is `$ARGUMENTS`; all
Rosey shims standardise on it.

### 4.5 No README inside skills

Skills are for agents, not humans. `README.md`, `CHANGELOG.md`, and
`INSTALLATION_GUIDE.md` inside a skill directory are anti-patterns; agents
do not read them and they bloat the skill listing.

This file is the exception that proves the rule: it lives in `agents/rosey/`,
not inside a skill, because it documents the design of a specialist agent
for human contributors.

## 5. Cross-platform notes

### 5.1 Claude Code

Custom commands and skills are merging into one surface: both
`.claude/commands/x.md` and `.claude/skills/x/SKILL.md` yield `/x`. Skill
content stays in context after invocation, so skill bodies must stay
concise. Memory files (`CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/*.md`)
target 200 lines or fewer. Subagents have their own context, tools, and
system prompt; fresh subagents do not see parent history, while forks
inherit it and share the parent prompt cache.

### 5.2 OpenCode

Commands accept `description`, `agent`, `model`, and `subtask` frontmatter
and run a command body as a literal user prompt. `$1..$9` and `$ARGUMENTS`
work as on Pi. `model:` was ignored on builds at and below 0.6.4; treat it
as a hint rather than a guarantee. Binding a command to an agent via
`agent: rosey` is how Rosey shims route on OpenCode.

### 5.3 Pi

Pi loads skills leniently from `~/.pi/agent/skills/`, `~/.agents/skills/`,
`.pi/skills/`, and `.agents/skills/`. Skills are invoked as `/skill:name`;
prompt templates as `/<name>`. Pi has no agent-scoped command namespace, so
commands live in a flat namespace. Pi's `prompt-templates` support `$1..$9`,
`$@`, `$ARGUMENTS`, and `${@:N}` slicing. Pi may not auto-invoke skills on
description alone; user prompting or explicit `/skill:name` is sometimes
needed.

### 5.4 Codex

Codex implements the Agent Skills open spec and loads from `.agents/skills/`
in the repo and `$HOME/.agents/skills` globally. The skill listing is
capped at roughly 2% of the context window, so descriptions must front-load
the use case. Codex custom prompts (`/prompts:<name>`) are deprecated;
skills are the supported route for both explicit and implicit invocation.
`AGENTS.md` is the Codex memory file with a 32 KiB project-doc cap and
`AGENTS.override.md` for nearest-wins overrides.

## 6. References

Authoritative sources cited across the four research documents that informed
Rosey's design. URLs preserved verbatim.

### 6.1 The `agents.md` and Agent Skills specs

- Agent Skills open specification: https://agentskills.io/specification
- Agent Skills spec source on GitHub: https://github.com/agentskills/agentskills/blob/main/docs/specification.mdx
- `agents.md` home page: https://agents.md/

### 6.2 Anthropic - skills, agents, memory, prompting

- Skill authoring best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Claude Code skills (extended doc): https://code.claude.com/docs/en/skills.md
- Extend Claude with skills: https://docs.anthropic.com/en/docs/claude-code/skills
- Create custom subagents: https://docs.anthropic.com/en/docs/claude-code/sub-agents
- How Claude remembers your project (CLAUDE.md): https://code.claude.com/docs/en/memory
- Memory: https://docs.anthropic.com/en/docs/claude-code/memory
- Output styles: https://docs.anthropic.com/en/docs/claude-code/output-styles
- Prompting best practices: https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/system-prompts
- Chain prompts (XML tags, role-setting): https://docs.anthropic.com/claude/docs/chain-prompts
- Best practices for Claude Code: https://code.claude.com/docs/en/best-practices
- CLAUDE.md context (Help Center): https://support.claude.com/en/articles/14553240
- Building effective agents: https://www.anthropic.com/engineering/building-effective-agents
- Custom skills (Help Center): https://support.anthropic.com/en/articles/12512198-creating-custom-skills
- Prompt caching: https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
- Hooks reference: https://docs.anthropic.com/en/docs/claude-code/hooks
- Slash commands (SDK): https://code.claude.com/docs/en/agent-sdk/slash-commands
- `claude-code` `skill-development` skill: https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/skill-development/SKILL.md
- `claude-code` `agent-development` skill: https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/agent-development/SKILL.md
- `claude-code` `command-development` skill: https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/command-development/README.md

### 6.3 OpenAI - Codex, agents, prompting

- Codex Agent Skills: https://developers.openai.com/codex/skills
- Codex customisation concepts: https://developers.openai.com/codex/concepts/customization
- Custom instructions with AGENTS.md: https://developers.openai.com/codex/guides/agents-md
- Codex custom prompts (deprecated): https://developers.openai.com/codex/custom-prompts
- Codex CLI README: https://github.com/openai/codex/blob/9a8730f3/codex-cli/README.md
- Codex system prompt source: https://github.com/openai/codex/blob/main/codex-rs/core/prompt.md
- `skill-creator` skill: https://github.com/openai/skills/blob/main/skills/.system/skill-creator/SKILL.md
- Prompting (Responses API): https://developers.openai.com/api/docs/guides/prompting
- Agent definitions: https://developers.openai.com/api/docs/guides/agents/define-agents
- Agent orchestration and handoffs: https://developers.openai.com/api/docs/guides/agents/orchestration
- GPT-5.1 prompting guide: https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-1_prompting_guide
- Best practices for prompt engineering: https://help.openai.com/en/articles/6654000
- Prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- Prompt Caching 201 (Cookbook): https://developers.openai.com/cookbook/examples/prompt_caching_201

### 6.4 Google - Gemini prompting

- System instructions intro: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/prompts/system-instruction-introduction
- Prompt design strategies: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/prompts/prompt-design-strategies

### 6.5 Pi

- Skills documentation: https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md
- Prompt templates documentation: https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/prompt-templates.md
- Substitution source: https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/src/core/prompt-templates.ts
- Usage and RPC: https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/usage.md

### 6.6 OpenCode, Cursor, Aider

- OpenCode commands: https://opencode.ai/docs/commands
- OpenCode commands (mirror): https://github.com/anomalyco/opencode/blob/dev/packages/web/src/content/docs/commands.mdx
- OpenCode-Book command system chapter: https://www.opencodebook.xyz/en/chapter_14_skill_system/14.3_command_system
- OpenCode `model:` ignored bug: https://github.com/sst/opencode/issues/2461
- Cursor custom commands: https://docs.cursor.com/en/agent/custom-commands
- Aider in-chat commands: https://aider.chat/docs/usage/commands.html

### 6.7 Community references

- RedKenrok `writing-skill-md`: https://raw.githubusercontent.com/RedKenrok/skills/refs/heads/main/skills/writing-skill-md/SKILL.md
- `mgechev/skills-best-practices`: https://github.com/mgechev/skills-best-practices
- OpenCode `command-creator` (community): https://playbooks.com/skills/igorwarzocha/opencode-workflows/command-creator
