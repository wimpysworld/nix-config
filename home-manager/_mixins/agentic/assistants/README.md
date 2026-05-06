# AI Agents

Fourteen specialist agents, 31 commands, and seven skills - composed by Nix from a single source tree and delivered to Claude Code, OpenCode, Codex, and Pi Agent without duplication.

The Nix composition is the delivery mechanism, not the strategy. Everything below - the prompt hierarchy, agent specialisation, model selection, context-efficiency constraints, and orchestration patterns - is a general approach to prompt and context engineering. The output is plain Markdown files with YAML frontmatter. If you use Claude Code or OpenCode directly, you can recreate any part of this by placing files in the right directories.

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

Each file is Markdown with YAML frontmatter specifying `name`, `description`, and optionally `model`. The prompt body follows the `---` delimiters. No build step required - drop the files in and they work.

## Contents

- [Prompt Hierarchy](#prompt-hierarchy)
- [Rosey - Principal Orchestrator](#rosey---principal-orchestrator)
- [Agents](#agents)
- [Model Selection](#model-selection)
- [Platform Delivery](#platform-delivery)

---

## Prompt Hierarchy

Instructions stack in four layers. Each layer narrows scope and increases specificity.

```
instructions/global.md          ← environment constraints, tool preferences, response standards
    └── AGENTS.md / CLAUDE.md   ← project-specific context, conventions, commands
            └── agent prompt    ← specialist persona, expertise, tools, constraints
                    └── command prompt  ← single task, optionally overrides model
```

**`instructions/global.md`** is the foundation. It sets universal constraints applied across every agent on every platform: LSP tool usage patterns, built-in file manipulation tools over shell commands, and response standards (British English, no preamble, no summary restatements, conclusions before reasoning). These rules never change per-project or per-agent; anything project-specific belongs in `AGENTS.md`.

Agent prompts inherit the global constraints and add specialisation. Command prompts inherit the agent context and focus on a single task - they stay short because the agent prompt already carries the persona, tools, and constraints. Commands that need deeper reasoning can override the parent model without rewriting the agent.

---

## Rosey - Principal Orchestrator

Rosey coordinates the team. She never implements, researches, or reads files directly. Her sole job is to understand the task, select the right agent, write a tight delegation prompt, and relay the result verbatim.

**Model:** `sonnet` (Claude Code) / `anthropic/claude-opus-4-7` (OpenCode)

### Session Priming

Every session begins with `/ready We are going to <broad activity description>`. This is a step-back prompt ([Zheng et al., 2023](https://arxiv.org/abs/2310.06117)) - an abstraction-first technique that weights the model's attention toward the relevant domain before specifics arrive. The description stays deliberately vague ("document my MCP configuration", not "write a README for the assistants directory") so the model activates broad domain knowledge rather than narrowing prematurely. Detailed instructions follow in subsequent messages once the model's attention is oriented.

### Context-Efficient Orchestration

Rosey's context window is permanent and finite. Sub-agent context windows are ephemeral and cheap. Every file read, code search, or web fetch Rosey performs displaces future coordination capacity. Her prompt bans these operations entirely - no exceptions:

> *Never read files, search code, or fetch web content. If you lack information to write a delegation prompt, tell the sub-agent what to discover.*

When Rosey lacks context, she delegates the discovery. Two sub-agent calls cost less than one file read into her permanent context. This asymmetry drives the entire orchestration pattern.

Sub-agent output is relayed verbatim - no summarising, no paraphrasing, no reformatting. Rosey's only permitted addition after a relay is a short follow-up question or proposed next action. This keeps the user's visible output at sub-agent quality, not a compressed proxy of it.

### Response Discipline

Every delegation prompt Rosey writes includes a response discipline block instructing the sub-agent how to respond:

> *Your response lands in a long-lived coordinator's context window. Every token counts. No preamble, no restating the task, no explaining which tools were used, no summarising what was already known. Artefacts returned raw. Reports use structured format with headings. Dense, not conversational.*

This constraint propagates context efficiency beyond Rosey herself. Sub-agents that pad their output with "I'll help you with that" or recap the task description waste tokens in the coordinator's permanent context. The discipline block eliminates this at source.

The same writing principles appear in every agent prompt, not just delegated tasks. Each agent carries a writing discipline section banning LLM-tell words (pivotal, seamless, leverage, delve, etc.), superficial "-ing" analysis ("ensuring reliability"), puffery, didactic disclaimers ("it's important to note"), and summary restatements. Active voice, positive form, concrete language, conclusions before reasoning, one statement per fact. These constraints produce tighter output regardless of whether an agent is called by Rosey or invoked directly.

### Prompt Style

Rosey's prompt engineering follows explicit rules about what works and what doesn't:

- **Imperatives over explanations** - "Focus on X" not "You should focus on X"
- **Constraints over descriptions** - say what to do and not do
- **Decision criteria over vague terms** - "files changed in last 5 commits" not "recently modified"
- **Examples only when essential** - subjective style, judgment calls, complex formats

Patterns actively removed: pre/post checklists, self-review instructions, verbose temporal breakdowns ("Before/During/After"), generic instructions ("be proactive", "ask clarifying questions"), vague terms without criteria ("meaningful", "high-impact"), and repeated constraints. Patterns preserved: YAML frontmatter descriptions, output format templates, few-shot examples for judgment tasks, explicit constraints, tool-specific guidance, and numeric limits.

### Token Constraints and Prompt Caching

Rosey's prompt engineering constraints are precise:

- 500-800 tokens per agent prompt (1,200 max for prompts with examples)
- Total system context under 10K tokens for near-100% instruction compliance
- 10-20K tokens is viable but compliance drops to ~60%

These numbers reflect two separate concerns.

**Compliance.** Instructions compete for attention. As the number of constraints in a prompt increases, the model's ability to satisfy all of them simultaneously degrades non-linearly. [Harada et al. (2025)](https://aclanthology.org/2025.findings-emnlp.896/) measured this directly: Claude 3.5 Sonnet followed a single instruction 95% of the time but dropped to 48% with ten simultaneous instructions. GPT-4o fell from 94% to 21% over the same range. Separately, [Liu et al. (2023)](https://arxiv.org/abs/2307.03172) showed that information positioned in the middle of long contexts is used less effectively than information at the start or end - the "lost in the middle" effect. Anthropic's own [prompt engineering guidance](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices) recommends being clear and direct, preferring specific constraints over verbose descriptions. The 10K token target and compliance percentages in Rosey's prompt are derived from empirical testing against these published baselines rather than from a single source.

**Prompt caching.** Claude [caches the system prompt](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) prefix across turns using KV cache representations. The cache activates above a [minimum token threshold](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) that varies by model:

| Model | Minimum cacheable tokens |
|-------|--------------------------|
| Claude Opus 4.6 / 4.5 | 4,096 |
| Claude Sonnet 4.6 | 2,048 |
| Claude Sonnet 4.5 / 4 / 3.7 | 1,024 |
| Claude Haiku 4.5 | 4,096 |

Cache entries have a 5-minute TTL (refreshed on hit, with an optional 1-hour TTL at 2x cost). A compact, stable system prompt (global rules + agent prompt + project instructions) that stays consistent across turns produces reliable cache hits - lower latency and lower cost per session. A bloated or variable prompt defeats the cache by changing the prefix hash. The 500-800 token target per agent prompt keeps the agent's contribution small enough that the combined system context stays within practical cache boundaries even when project-level instructions and tool definitions are added.

Rosey's `update-assistant` command applies these constraints retroactively - stripping ineffective patterns (pre/post checklists, verbose temporal breakdowns, generic LLM behaviours, repeated constraints) while preserving output format templates, few-shot examples, decision criteria, and explicit constraints.

### Commands

Rosey's commands handle agent orchestration and prompt engineering. Several override the parent `sonnet` model with `opus` for tasks requiring deeper reasoning.

| Command | Model | Purpose |
|---------|-------|---------|
| `create-assistant` | `opus` | Generate a new agent prompt from requirements |
| `create-instructions` | `opus` | Create `AGENTS.md` from codebase analysis |
| `create-skill` | `opus` | Create a reusable `SKILL.md` |
| `review-instructions` | `opus` | Assess prompts against high/low-value pattern criteria |
| `update-assistant` | `sonnet` | Apply context-efficiency pass to an existing agent |
| `update-instructions` | `sonnet` | Apply targeted changes or consolidate scattered instruction files |
| `offboard` | `sonnet` | Write structured handover document for next engineer |

The `opus` commands involve prompt design judgements - choosing what to include, what to cut, when examples are essential - that benefit from the stronger reasoning model. The `sonnet` commands follow a clear structure (`update-assistant` has a template; `offboard` has a fixed section schema) where sonnet is sufficient.

---

## Agents

### Batfink - Infrastructure Security Auditor

Infrastructure security auditor assessing configuration hardening, defensive resilience, and blast radius across cloud, container, and network infrastructure. Identifies misconfigurations, privilege escalation paths, and lateral movement risks. Every finding is mapped to concrete remediation.

**Model:** `opus` (Claude Code) / `gpt-5.4` (OpenCode) - infrastructure security assessment requires reasoning across interacting systems, trust boundaries, and attack chains simultaneously.

| Command | Purpose |
|---------|---------|
| `audit-infra-security` | Structured 5-phase infrastructure security audit |

---

### Brain - Test Engineer

Pragmatic test engineer identifying high-impact unit tests that catch real bugs. Analyses git history to find frequently-fixed files, searches GitHub issues for bug patterns, and reads existing tests before recommending new ones. Focuses on coverage gaps that matter rather than coverage numbers.

**Model:** `opus` (Claude Code) / `gpt-5.4` (OpenCode) - deep codebase analysis with risk-based reasoning requires the strongest model.

| Command | Purpose |
|---------|---------|
| `review-tests` | Analyse codebase for high-value test additions |

---

### Casper - Technical Writer

Ghost writer emulating Martin Wimpress's blog voice: enthusiastic, conversational British English combining Linux expertise with accessible humour. First-person narrative, direct reader address, British colloquialisms integrated naturally. Loads `prose-style-reference` for extended writing.

**Model:** `sonnet` (Claude Code) / `anthropic/claude-opus-4-7` (OpenCode) - voice emulation and style calibration suit the mid-tier model.

| Command | Purpose |
|---------|---------|
| `draft-blog-post` | Write a blog post in Martin's voice |
| `draft-video-script` | Write a video script in Martin's voice |

---

### Dexter - Nix Expert

Expert in Nix, Nixpkgs, NixOS, Home Manager, and nix-darwin. Always verifies packages and options exist before recommending them using the NixOS MCP tools. Prefers modern Nix: flakes and new CLI. Explains rationale behind every suggestion.

**Model:** `opus` (Claude Code) / `gpt-5.4` (OpenCode) - Nix's lazy evaluation semantics, module system interactions, and packaging edge cases require deep reasoning.

No standalone commands. Dexter is invoked directly for Nix questions.

---

### Dibble - Code Security Auditor

Code security auditor methodically patrolling codebases for vulnerabilities, insecure patterns, and dependency risks. Cites CWE and OWASP classifications for every finding. Distinguishes confirmed vulnerabilities from theoretical risks and prioritises by exploitability.

**Model:** `opus` (Claude Code) / `gpt-5.4` (OpenCode) - vulnerability identification requires reasoning across data flows, trust boundaries, and exploitation conditions; the strongest model reduces false negatives.

| Command | Purpose |
|---------|---------|
| `audit-code-security` | Structured 5-phase code security audit |

---

### Donatello - Implementation Engineer

Precise implementation engineer executing code changes from specifications. Reads related files before any implementation, reuses existing utilities before writing new ones, identifies blockers early. Preserves existing conventions and architectural decisions.

**Model:** `opus` (Claude Code) / `gpt-5.4` (OpenCode) - multi-file implementation with consistency requirements across the codebase demands the strongest reasoning.

| Command | Purpose |
|---------|---------|
| `create-code-plan` | Break implementation into atomic, sequenced tasks |
| `implement-code` | Execute tasks from a plan |
| `review-feedback` | Classify PR review comments: critical / robustness / quality / style |

---

### Garfield - Git Workflow Specialist

Git workflow specialist enforcing Conventional Commits 1.0.0. Analyses existing commit history for project-specific scope patterns before writing messages. Handles type classification, scope determination, and breaking change footers.

**Model:** `haiku` (Claude Code) / `gpt-5-mini` (OpenCode) - commit message generation is a structured, deterministic task with clear rules. The smallest model handles it correctly at minimum cost.

| Command | Purpose |
|---------|---------|
| `create-conventional-commit` | Generate a commit message (does not execute the commit) |
| `create-pull-request` | Push branch and create GitHub PR via `gh` |

---

### Gonzales - Performance Specialist

Performance optimisation specialist focused on user-perceivable improvements. Rates optimisations on a 1-10 impact scale. Only recommends changes where the user-perceivable effect justifies the maintainability cost.

**Model:** `opus` (Claude Code) / `gpt-5.4` (OpenCode) - identifying true bottlenecks versus theoretical micro-optimisations requires reasoning across algorithmic complexity, memory patterns, and I/O behaviour simultaneously.

| Command | Purpose |
|---------|---------|
| `review-performance` | Identify optimisation opportunities with impact ratings |

---

### Melody - Audio Quality Analyst

Interprets objective audio metrics into perceptual descriptions: how a recording actually sounds to a listener. Specialises in spectral analysis, EBU R128 loudness measurement, dynamic range, and before/after processing comparison.

**Model:** `sonnet` (Claude Code) / `anthropic/claude-opus-4-7` (OpenCode) - metric interpretation follows structured lookup tables; sonnet handles this accurately.

| Command | Purpose |
|---------|---------|
| `analyse-audio-levels` | Diagnose recording issues from level metrics |
| `analyse-audio-processing` | Compare before/after metrics, detect processing artefacts |

---

### Penfold - Research Generalist

Research partner for exploring ideas, generating options, and framing problems for downstream specialists. Synthesises findings into dense, actionable overviews. Flags uncertainty explicitly (confidence: high/medium/low). Produces handoffs specialists can use without clarification.

**Model:** `opus` (Claude Code) / `gpt-5.4` (OpenCode) - research synthesis, problem framing, and trade-off analysis produce better direct-use results on the stronger model; specialist agents still handle domain-specific validation.

| Command | Purpose |
|---------|---------|
| `create-overview` | Research synthesis document |
| `review-plan` | Meticulous plan review with cited sources |
| `review-alignment` | Audit two documents for alignment gaps |
| `create-implementation-proposal` | Bridge research findings into a specification |
| `deep-research` | Multi-round research tracked in `RESEARCH-PLAN.md` |

---

### Penry - Code Reviewer

Maintainability specialist reviewing for simplification, duplication, dead code, and naming clarity. Every suggestion is small, safe, and preserves exact functionality. Uses an impact scale; only flags changes where the maintainability benefit justifies the diff.

**Model:** `sonnet` (Claude Code) / `anthropic/claude-opus-4-7` (OpenCode) - pattern recognition across a codebase suits sonnet; the review criteria are explicit enough that the stronger model adds little.

| Command | Purpose |
|---------|---------|
| `review-code` | Maintainability review: dead code, simplification, duplication |
| `review-code-smell` | Hunt for genuine code smells: god objects, feature envy, etc. |
| `review-stdlib` | Identify reimplemented standard library functionality |

---

### Pepe - LÖVE 2D Game Developer

Expert in LÖVE 2D 11.5 and Lua 5.1/LuaJIT 2.1. Provides complete, runnable code examples. Selects architecture (plain tables / OOP / ECS) based on project scope. Verifies LÖVE API syntax via Context7 before recommendations.

**Model:** `sonnet` (Claude Code) / `anthropic/claude-opus-4-7` (OpenCode) - game development assistance is a well-defined domain; sonnet produces accurate Lua and LÖVE API usage.

No standalone commands. Pepe is invoked directly for LÖVE questions.

---

### Velma - Documentation Architect

Documentation architect creating technically precise guides through progressive disclosure. Transforms codebases into accessible documentation. Loads `prose-style-reference` for extended writing tasks.

**Model:** `sonnet` (Claude Code) / `anthropic/claude-opus-4-7` (OpenCode) - documentation writing is a structured task where voice, clarity, and organisation matter more than deep reasoning.

| Command | Purpose |
|---------|---------|
| `create-readme` | Write README following standard structure |
| `update-docs` | Update documentation to reflect code changes |
| `create-docs-plan` | Audit documentation, identify gaps, prioritise improvements |

---

## Model Selection

Three tiers map to task complexity:

| Tier | Claude Code | OpenCode | Used for |
|------|------------|----------|----------|
| Heavy reasoning | `opus` | `gpt-5.4` | Deep analysis, research synthesis, complex implementation, Nix expertise, prompt engineering, security auditing |
| General purpose | `sonnet` | `anthropic/claude-opus-4-7` | Writing, code review, audio analysis, game dev |
| Deterministic tasks | `haiku` | `gpt-5-mini` | Structured formatting with clear rules (Garfield only) |

**Why some commands override the parent model:** An agent's base model reflects its typical workload. Some commands within that agent require a different level of reasoning. Rosey runs on `sonnet` because coordination - writing delegation prompts, relaying output - suits the mid-tier model. Her `create-assistant` and `review-instructions` commands override to `opus` because prompt design requires weighing what to include, what to cut, and when examples are essential - judgements where the stronger model produces measurably better output. Penfold now sits in the heavy-reasoning tier because direct research synthesis and framing work performed better on `opus` and `gpt-5.4` than on the mid-tier models. The override isolates extra cost to the specific agents or commands that need it.

---

## Platform Delivery

`compose.nix` reads the source tree and generates platform-specific output. Each agent has one `prompt.md` and per-platform `header.<platform>.yaml` files for Claude Code and OpenCode. Codex agents use `header.codex.toml` for role-local config, and Codex command skills can use `header.codex.toml` with `spawn-agent = true` to delegate through `spawn_agent`.

Pi Agent rendering lives in `default.nix` beside the shared secret-aware Traya rendering. Generated Pi subagents use `systemPromptMode: append`, inherit project context and skills, and set `maxSubagentDepth: 0` so child sessions cannot delegate further. Prompt templates carry `description` and reuse Claude `argument-hint` values where present.

OpenCode `permission` headers are not mapped to Pi. Pi supports an explicit `tools` allowlist for subagents, but OpenCode's allow/deny permission model is not equivalent.

| Platform | Agents | Commands | Global rules | Skills |
|----------|--------|----------|-------------|--------|
| Claude Code | `~/.claude/agents/*.agent.md` | `~/.claude/commands/*.prompt.md` | `~/.claude/rules/instructions.md` | `~/.claude/skills/*/SKILL.md` |
| OpenCode | `~/.config/opencode/agents/*.agent.md` | `~/.config/opencode/commands/*.prompt.md` | `rules` option | `~/.config/opencode/skills/*/SKILL.md` |
| Codex | `~/.config/codex/agents/*.toml` | `~/.config/codex/skills/*/SKILL.md` | `programs.codex.custom-instructions` | `~/.config/codex/skills/*/SKILL.md` |
| Pi Agent | `~/.pi/agent/agents/*.md` | `~/.pi/agent/prompts/*.md` | `~/.pi/agent/AGENTS.md` | `~/.pi/agent/skills/*/SKILL.md` |

### Skills

Seven skills provide background knowledge and reference material. The original three load automatically; the four new skills are user-invocable.

**Always loaded (agent-invoked):**

| Skill | Loaded by | Purpose |
|-------|-----------|---------|
| `meet-the-agents` | Rosey (every session) | Agent registry - roles, delegation triggers |
| `prose-style-reference` | Casper, Velma | Extended Strunk composition rules, AI pattern catalogue |
| `writing-clearly-and-concisely` | Any agent writing for humans | Core six principles, banned words and patterns |

**User-invocable (loaded contextually):**

| Skill | Purpose |
|-------|---------|
| `gh` | GitHub CLI reference - PR creation, issue management, releases |
| `code-security` | OWASP Top 10 and infrastructure security rules sourced from `semgrep/skills` |
| `llm-security` | OWASP Top 10 for LLM 2025 sourced from `semgrep/skills` |
| `semgrep` | Semgrep CLI usage and custom rule creation reference |
