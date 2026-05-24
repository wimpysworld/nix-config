# AI Agents

Twelve specialist agents, 38 commands, twelve physical skills, and one generated skill - composed by Nix from a single source tree and delivered to Claude Code, OpenCode, Codex, and Pi Agent without duplication.

The Nix composition is the delivery mechanism, not the strategy. Everything below - the prompt hierarchy, agent specialisation, model selection where pinned, context-efficiency constraints, and orchestration patterns - is a general approach to prompt and context engineering. The output is plain Markdown files with YAML frontmatter. If you use Claude Code or OpenCode directly, you can recreate any part of this by placing files in the right directories.

### File layout

**Claude Code:**

```
~/.claude/
├── rules/instructions.md          # Global instructions (loaded every session)
├── agents/<name>.agent.md          # Agent definitions (selectable with --agent)
├── commands/<name>.prompt.md       # Slash commands (invocable with /<name>)
└── skills/<name>/SKILL.md          # Reference knowledge (loaded contextually)
```

**OpenCode:**

```
~/.config/opencode/
├── agents/<name>.agent.md          # Agent definitions (selectable with --agent)
├── commands/<name>.prompt.md       # Slash commands (invocable with /<name>)
└── skills/<name>/SKILL.md          # Reference knowledge (loaded contextually)
```

Global instructions in OpenCode are set via the `rules` option in `settings.json` rather than a file.

**Pi Agent:**

```
~/.pi/agent/
├── AGENTS.md                       # Global instructions (loaded every session)
├── agents/<name>.md                # Subagent definitions for pi-subagents
├── prompts/<name>.md               # Prompt templates (invocable with /<name>)
└── skills/<name>/SKILL.md          # Agent Skills (loaded contextually)
```

Pi Agent resources are rendered here and consumed by `../pi`, which owns the Pi package, runtime wrapper, settings, MCP adapter, subagent extension config, and theme files.

Each file is Markdown with YAML frontmatter. Claude Code, Codex, and Pi headers may pin models. OpenCode headers intentionally omit `model` and honour the model currently selected in OpenCode, so users can switch Anthropic and OpenAI models manually. The prompt body follows the `---` delimiters. No build step required - drop the files in and they work.

## Contents

- [Prompt Hierarchy](#prompt-hierarchy)
- [Global Instructions](#global-instructions)
- [Agents](#agents)
- [Model Selection](#model-selection)
- [Platform Delivery](#platform-delivery)
- [Provider Routing](#provider-routing)

---

## Prompt Hierarchy

Instructions stack in four layers. Each layer narrows scope and increases specificity.

```
instructions/global.md          ← environment constraints, tool preferences, response standards
    └── AGENTS.md / CLAUDE.md   ← project-specific context, conventions, commands
            └── agent prompt    ← specialist persona, expertise, tools, constraints
                    └── command prompt  ← single task, optionally overrides model
```

**`instructions/global.md`** is the role-neutral foundation for every platform. It sets delegation triggers, fresh-context defaults, trust boundaries, reference-tool preferences, GitHub safety, LSP guidance, file rules, response standards, and verbatim relay. Full specialist routing and output contracts live in the generated `delegate-task` skill.

Agent prompts inherit the global constraints and add specialisation. Command prompts inherit the agent context and focus on a single task - they stay short because the agent prompt already carries the persona, tools, and constraints. Commands that need deeper reasoning can override the parent model without rewriting the agent.

---

## Global Instructions

`instructions/global.md` has no persona. It tells the coordinator to use `delegate-task` before parent-thread exploration for non-trivial tool, file, research, implementation, review, validation, or documentation work.

### Session Priming

Every session begins with `/ready We are going to <broad activity description>`. This is a step-back prompt ([Zheng et al., 2023](https://arxiv.org/abs/2310.06117)) - an abstraction-first technique that weights the model's attention toward the relevant domain before specifics arrive. The description stays deliberately vague ("document my MCP configuration", not "write a README for the assistants directory") so the model activates broad domain knowledge rather than narrowing prematurely. Detailed instructions follow in subsequent messages once the model's attention is oriented.

### Context-Efficient Orchestration

Parent context is permanent and finite. Specialist context windows are ephemeral. Protect the parent window by using fresh context for file reads, code search, web research, implementation, audits, and other tool-heavy work. Fork only when the user explicitly requires it or when the parent transcript is essential.

When the coordinator lacks context, it delegates discovery instead of researching first. `delegate-task` owns routing, packet fields, the response contract, default discipline, fresh-context rule, and relay policy. Nix work routes to Donatello with the `nix` skill.

### Response Discipline

Global response rules stay compact: concise peer-to-peer British English, no em dashes, one statement per fact, fenced blocks for code, file content, and commit messages. A single specialist output is relayed verbatim, with intervention only for safety.

### Standalone Commands

| Command       | Purpose                                                |
| ------------- | ------------------------------------------------------ |
| `ack`         | Acknowledge a phase or message and yield               |
| `botsnack`    | Celebrate agent work                                   |
| `collaborate` | Read an implementation plan and prepare to collaborate |
| `orientate`   | Inspect the repository and report orientation notes    |
| `ready`       | Prime the session for a broad activity                 |

---

## Agents

### Rosey - Prompt & Skill Specialist

Prompt and skill specialist for agent prompts, skills, commands, and instruction files. Rosey edits these artefacts directly, applies context-efficiency constraints, and keeps prompt guidance short enough to hold. She is not the global coordinator; `instructions/global.md` owns default delegation policy.

**Model:** `sonnet` (Claude Code) - prompt maintenance is structured enough for the mid-tier model. OpenCode uses the current session model.

Rosey's prompt engineering rules:

- Imperatives over explanations - "Focus on X" not "You should focus on X"
- Constraints over descriptions - say what to do and not do
- Decision criteria over vague terms - "files changed in last 5 commits" not "recently modified"
- Examples only when essential - subjective style, judgment calls, complex formats

Prompt constraints:

- 500-800 tokens per agent prompt, 1,200 max for prompts with examples
- Total system context under 10K tokens for near-100% instruction compliance
- 10-20K tokens is viable but compliance drops to ~60%

Compact, stable system prompts preserve Claude prompt-cache hits; bloated or variable prompt prefixes defeat caching. Rosey's `update-assistant` command removes ineffective patterns while preserving output templates, few-shot examples, decision criteria, explicit constraints, tool-specific guidance, and numeric limits.

| Command            | Model    | Purpose                                                           |
| ------------------ | -------- | ----------------------------------------------------------------- |
| `create-assistant` | `opus`   | Generate a new agent prompt from requirements                     |
| `create-agents-md` | `opus`   | Create `AGENTS.md` from codebase analysis                         |
| `create-skill`     | `opus`   | Create a reusable `SKILL.md`                                      |
| `update-assistant` | `sonnet` | Apply context-efficiency pass to an existing agent                |
| `update-agents-md` | `sonnet` | Apply targeted changes or consolidate scattered instruction files |
| `update-skill`     | `opus`   | Improve an existing reusable skill                                |
| `handover`         | `sonnet` | Write structured handover document for next engineer              |

---

### Batfink - Infrastructure Security Auditor

Infrastructure security auditor assessing configuration hardening, defensive resilience, and blast radius across cloud, container, and network infrastructure. Identifies misconfigurations, privilege escalation paths, and lateral movement risks. Every finding is mapped to concrete remediation.

**Model:** `opus` (Claude Code) - infrastructure security assessment requires reasoning across interacting systems, trust boundaries, and attack chains simultaneously.

| Command                | Purpose                                          |
| ---------------------- | ------------------------------------------------ |
| `audit-infra-security` | Structured 5-phase infrastructure security audit |

---

### Brain - Test Engineer

Pragmatic test engineer identifying high-impact unit tests that catch real bugs. Analyses git history to find frequently-fixed files, searches GitHub issues for bug patterns, and reads existing tests before recommending new ones. Focuses on coverage gaps that matter rather than coverage numbers.

**Model:** `opus` (Claude Code) - deep codebase analysis with risk-based reasoning requires the strongest model.

| Command        | Purpose                                        |
| -------------- | ---------------------------------------------- |
| `review-tests` | Analyse codebase for high-value test additions |

---

### Casper - Technical Writer

Ghost writer emulating Martin Wimpress's blog voice: enthusiastic, conversational British English combining Linux expertise with accessible humour. First-person narrative, direct reader address, British colloquialisms integrated naturally. Loads `prose-style-reference` for extended writing.

**Model:** `sonnet` (Claude Code) - voice emulation and style calibration suit the mid-tier model.

| Command              | Purpose                                |
| -------------------- | -------------------------------------- |
| `draft-blog-post`    | Write a blog post in Martin's voice    |
| `draft-video-script` | Write a video script in Martin's voice |

---

### Dibble - Code Security Auditor

Code security auditor methodically patrolling codebases for vulnerabilities, insecure patterns, and dependency risks. Cites CWE and OWASP classifications for every finding. Distinguishes confirmed vulnerabilities from theoretical risks and prioritises by exploitability.

**Model:** `opus` (Claude Code) - vulnerability identification requires reasoning across data flows, trust boundaries, and exploitation conditions; the strongest model reduces false negatives.

| Command               | Purpose                                |
| --------------------- | -------------------------------------- |
| `audit-code-security` | Structured 5-phase code security audit |

---

### Donatello - Implementation Engineer

Precise implementation engineer executing code changes from specifications. Reads related files before any implementation, reuses existing utilities before writing new ones, identifies blockers early. Preserves existing conventions and architectural decisions. Loads the `nix` skill for Nix, NixOS, Home Manager, nix-darwin, flakes, packages, modules, and `.nix` files. Loads the `love` skill for LÖVE 2D and Lua 5.1/LuaJIT 2.1 game development.

**Model:** `opus` (Claude Code) - multi-file implementation with consistency requirements across the codebase demands the strongest reasoning.

| Command            | Purpose                                                              |
| ------------------ | -------------------------------------------------------------------- |
| `create-code-plan` | Break implementation into atomic, sequenced tasks                    |
| `implement-code`   | Execute tasks from a plan                                            |
| `review-feedback`  | Classify PR review comments: critical / robustness / quality / style |
| `peer-review`      | Give an ecosystem-specific codebase verdict                          |

---

### Garfield - Git Workflow Specialist

Git workflow specialist enforcing Conventional Commits 1.0.0. Analyses existing commit history for project-specific scope patterns before writing messages. Handles type classification, scope determination, and breaking change footers.

**Model:** `haiku` (Claude Code) - commit message generation is a structured, deterministic task with clear rules. The smallest Claude Code model handles it correctly at minimum cost.

| Command                      | Purpose                                                 |
| ---------------------------- | ------------------------------------------------------- |
| `create-conventional-commit` | Generate a commit message (does not execute the commit) |
| `create-pull-request`        | Push branch and create GitHub PR via `gh`               |

---

### Gonzales - Performance Specialist

Performance optimisation specialist focused on user-perceivable improvements. Rates optimisations on a 1-10 impact scale. Only recommends changes where the user-perceivable effect justifies the maintainability cost.

**Model:** `opus` (Claude Code) - identifying true bottlenecks versus theoretical micro-optimisations requires reasoning across algorithmic complexity, memory patterns, and I/O behaviour simultaneously.

| Command              | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| `review-performance` | Identify optimisation opportunities with impact ratings |

---

### Melody - Audio Quality Analyst

Interprets objective audio metrics into perceptual descriptions: how a recording actually sounds to a listener. Specialises in spectral analysis, EBU R128 loudness measurement, dynamic range, and before/after processing comparison.

**Model:** `sonnet` (Claude Code) - metric interpretation follows structured lookup tables; sonnet handles this accurately.

| Command                    | Purpose                                                   |
| -------------------------- | --------------------------------------------------------- |
| `analyse-audio-levels`     | Diagnose recording issues from level metrics              |
| `analyse-audio-processing` | Compare before/after metrics, detect processing artefacts |

---

### Penfold - Research Generalist

Research partner for exploring ideas, generating options, and framing problems for downstream specialists. Synthesises findings into dense, actionable overviews. Flags uncertainty explicitly (confidence: high/medium/low). Produces handoffs specialists can use without clarification.

**Model:** `opus` (Claude Code) - research synthesis, problem framing, and trade-off analysis produce better direct-use results on the stronger model; specialist agents still handle domain-specific validation.

| Command                          | Purpose                                            |
| -------------------------------- | -------------------------------------------------- |
| `create-overview`                | Research synthesis document                        |
| `review-plan`                    | Meticulous plan review with cited sources          |
| `review-alignment`               | Audit two documents for alignment gaps             |
| `create-implementation-proposal` | Bridge research findings into a specification      |
| `deep-research`                  | Multi-round research tracked in `RESEARCH-PLAN.md` |

---

### Penry - Code Reviewer

Maintainability specialist reviewing for simplification, duplication, dead code, and naming clarity. Every suggestion is small, safe, and preserves exact functionality. Uses an impact scale; only flags changes where the maintainability benefit justifies the diff.

**Model:** `sonnet` (Claude Code) - pattern recognition across a codebase suits sonnet; the review criteria are explicit enough that the stronger model adds little.

| Command             | Purpose                                                        |
| ------------------- | -------------------------------------------------------------- |
| `review-code`       | Maintainability review: dead code, simplification, duplication |
| `review-code-smell` | Hunt for genuine code smells: god objects, feature envy, etc.  |
| `review-stdlib`     | Identify reimplemented standard library functionality          |

---

### Velma - Documentation Architect

Documentation architect creating technically precise guides through progressive disclosure. Transforms codebases into accessible documentation. Loads `prose-style-reference` for extended writing tasks.

**Model:** `sonnet` (Claude Code) - documentation writing is a structured task where voice, clarity, and organisation matter more than deep reasoning.

| Command            | Purpose                                                     |
| ------------------ | ----------------------------------------------------------- |
| `create-readme`    | Write README following standard structure                   |
| `update-docs`      | Update documentation to reflect code changes                |
| `create-docs-plan` | Audit documentation, identify gaps, prioritise improvements |

---

## Model Selection

Three Claude Code tiers map to task complexity:

| Tier                | Claude Code | Used for                                                                                         |
| ------------------- | ----------- | ------------------------------------------------------------------------------------------------ |
| Heavy reasoning     | `opus`      | Deep analysis, research synthesis, complex implementation, prompt engineering, security auditing |
| General purpose     | `sonnet`    | Writing, code review, audio analysis                                                             |
| Deterministic tasks | `haiku`     | Structured formatting with clear rules (Garfield only)                                           |

OpenCode headers never set `model`. OpenCode honours the user's currently selected model, which keeps manual switching between Anthropic and OpenAI models intact.

**Why some commands override the parent model:** An agent's base model reflects its typical Claude Code workload. Some commands within that agent require a different level of reasoning. Rosey runs on `sonnet` because routine prompt and instruction maintenance follows tight templates. Her `create-assistant`, `create-agents-md`, `create-skill`, and `update-skill` commands override to `opus` because prompt design requires weighing what to include, what to cut, and when examples are essential - judgements where the stronger model produces measurably better output. Penfold sits in the heavy-reasoning tier because direct research synthesis and framing work performed better on `opus` than on the mid-tier model.

---

## Platform Delivery

`compose.nix` reads the source tree and generates platform-specific output. Each agent has one `prompt.md` and per-platform headers: `header.claude.yaml`, `header.opencode.yaml`, `header.codex.toml`, and `header.pi.yaml`. Codex agents use `header.codex.toml` for role-local config, and Codex command skills can use `header.codex.toml` with `spawn-agent = true` to delegate through `spawn_agent`.

Pi composition routes through `compose.composeAgentFromPrompt "pi"` and `compose.composeCommand "pi"`. The agent-scoped command prelude ("Use the subagent tool to launch the `<agent>` agent...") is assembled in `default.nix` and wraps `compose.composePiCommandFromPrompt`, mirroring how the Codex side wraps `spawn_agent` guidance around skill bodies.

`header.pi.yaml` is optional. When absent, Pi subagents inherit three generated defaults: `systemPromptMode: append`, `inheritProjectContext: false`, and `inheritSkills: true`. The header file may carry any Pi-native frontmatter field: `model`, `thinking`, `tools`, `defaultContext`, `output`, `fallbackModels`, `maxSubagentDepth`, plus per-command `argument-hint`. Fields present in the file are appended verbatim, so explicit per-agent depth limits are preserved.

OpenCode `permission` headers are not mapped to Pi. Pi supports an explicit `tools` allowlist for subagents, but OpenCode's allow/deny permission model is not equivalent.

### Provider routing

Pi can route a subagent to a provider-specific model and/or reasoning effort
through extra `model-<provider>` and `thinking-<provider>` keys in the agent's
`header.pi.yaml`:

```yaml
model-anthropic: claude-haiku-4-5
model-openai-codex: gpt-5.4-mini
model-google: "gemini-3-flash"
thinking-openai-codex: xhigh
```

The suffix after `model-` or `thinking-` must match the active Pi provider
name exactly, including hyphens (this repo's default provider is
`openai-codex`, not `openai`). The value must be a plain scalar, with optional
matching single or double quotes. The Nix harvester uses a regex-only parser,
so block scalars, anchors, aliases, unmatched quotes, and unquoted values
containing `:` are ignored.

`thinking-<provider>` values are validated at evaluation time against
`off|minimal|low|medium|high|xhigh`; invalid values fail `nix eval` rather than
silently entering the generated map.

When both keys are present, Pi receives `provider/modelId:thinking`. When only
`thinking-<provider>` is set, the runtime reuses the active session model id
as the bare model, so the agent keeps the parent model and only its reasoning
effort changes.

This repo's convention is **explicit headers**: every named agent declares
`model-anthropic`, `model-openai-codex`, and `thinking-openai-codex` so the
active model and reasoning effort are visible in the agent's own header
rather than inferred from Pi's `defaultModel` and `defaultThinkingLevel`.
Additional providers (e.g. `model-google`) are added per-agent where
relevant. The router still supports thinking-only entries (the runtime then
reuses the active session model id), but explicit `model-<provider>` plus
`thinking-<provider>` is preferred.

Pi's global `defaultThinkingLevel = "medium"` and `defaultModel = "gpt-5.5"`
remain the fallback for the unnamed global prompt and any future agent that
omits a header.

Provider routing covers Pi's LLM tool-call path only. Slash commands such as
`/run`, `/chain`, `/parallel`, `/run-chain`, and prompt-template bridge calls
keep their normal Pi and `pi-subagents` model resolution.

Runtime behaviour lives in
[`../pi/extensions/provider-router/README.md`](../pi/extensions/provider-router/README.md).

### Prompt vs skill argument semantics

Pi exposes two surfaces that can take user input, and they handle arguments differently.

**Prompts** (`/<cmd>`) substitute placeholders inside the prompt body. The Pi-native syntax is `$1`, `$2`, `$@`, `$ARGUMENTS`, `${@:N}`, `${@:N:L}`. A prompt template that says "Review the plan at $1" receives the plan path as `$1` at invocation. This is the same syntax bash uses for positional parameters.

**Skills** (`/skill:<name>`) do not substitute. Trailing arguments after the skill invocation become a follow-up `User:` message appended after the skill body. A skill is reference content the model loads for context; trailing args are the user request that follows.

This split keeps the surfaces semantically clean: prompts take inputs, skills provide guidance. `argument-hint` in `header.pi.yaml` documents the expected positional arguments for prompt autocomplete; skills carry no equivalent because they do not pattern-match arguments.

| Platform    | Agents                                 | Commands                                  | Global rules                      | Skills                                 |
| ----------- | -------------------------------------- | ----------------------------------------- | --------------------------------- | -------------------------------------- |
| Claude Code | `~/.claude/agents/*.agent.md`          | `~/.claude/commands/*.prompt.md`          | `~/.claude/rules/instructions.md` | `~/.claude/skills/*/SKILL.md`          |
| OpenCode    | `~/.config/opencode/agents/*.agent.md` | `~/.config/opencode/commands/*.prompt.md` | `rules` option                    | `~/.config/opencode/skills/*/SKILL.md` |
| Codex       | `~/.config/codex/agents/*.toml`        | `~/.config/codex/skills/*/SKILL.md`       | `~/.config/codex/AGENTS.md`       | `~/.config/codex/skills/*/SKILL.md`    |
| Pi Agent    | `~/.pi/agent/agents/*.md`              | `~/.pi/agent/prompts/*.md`                | `~/.pi/agent/AGENTS.md`           | `~/.pi/agent/skills/*/SKILL.md`        |

### Skills

Shared skills provide background knowledge and reference material. Most are sourced from `skills/*/SKILL.md`; `delegate-task` is generated from the agent registry so delegation guidance cannot drift from the configured agents.

**Generated and agent-loaded:**

| Skill                           | Loaded by            | Purpose                                                                                                |
| ------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------ |
| `delegate-task`                 | Coordinator or user  | Generated routing, packet, response contract, relay policy                                             |
| `prose-style-reference`         | Casper, Velma        | Extended Strunk composition rules, AI pattern catalogue                                                |
| `writing-clearly-and-concisely` | Prose artefacts only | Condensed rules for docs, READMEs, blog posts, guides, scripts, long-form content                      |
| `write-skill`                   | Rosey or user        | Author or update an Agent Skill (`SKILL.md`) - frontmatter, layout, references, progressive disclosure |
| `write-agents-md`               | Rosey or user        | Author, update, or consolidate AGENTS.md / CLAUDE.md / .cursorrules project instruction files          |
| `write-assistant`               | Rosey or user        | Author or update an agent system prompt - persona, structure, voice, examples, constraints             |
| `nix`                           | Donatello            | Nix, NixOS, Home Manager, nix-darwin, flakes, packages, modules, registries                            |
| `love`                          | Donatello            | LÖVE 2D, LÖVE engine, `love2d`, `.love` archives, Lua 5.1/LuaJIT 2.1 game work                         |

**User-invocable support skills:**

| Skill           | Purpose                                                                      |
| --------------- | ---------------------------------------------------------------------------- |
| `gh`            | GitHub CLI reference - PR creation, issue management, releases               |
| `code-security` | OWASP Top 10 and infrastructure security rules sourced from `semgrep/skills` |
| `llm-security`  | OWASP Top 10 for LLM 2025 sourced from `semgrep/skills`                      |
| `semgrep`       | Semgrep CLI usage and custom rule creation reference                         |
