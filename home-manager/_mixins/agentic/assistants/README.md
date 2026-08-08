# AI Agents

Eleven specialist agents, 60 commands, twenty-three physical skills, and two generated skills - composed by Nix from a single source tree and delivered to each enabled Claude Code, OpenCode, Codex, and Pi Agent client without duplication.

Developer servers keep Pi Agent resources. Claude Code, OpenCode, and Codex resources are emitted only when those clients are enabled.

The Nix composition is the delivery mechanism, not the strategy. Everything below - the prompt hierarchy, agent specialisation, model selection where pinned, context-efficiency constraints, and orchestration patterns - is a general approach to prompt and context engineering. The portable source uses Markdown prompts with provider-specific headers, and Nix emits each client's native file layout. If you use Claude Code or OpenCode directly, you can recreate any part of this by placing files in the right directories.

### File layout

**Claude Code:**

```
~/.claude/
├── rules/instructions.md          # Global instructions (loaded every session)
├── output-styles/house-style.md   # Communication Rules in the system prompt
├── agents/<name>.md               # Agent definitions (selectable with --agent)
├── commands/<name>.md             # Slash commands (invocable with /<name>)
└── skills/<name>/SKILL.md          # Reference knowledge (loaded contextually)
```

**OpenCode:**

```
~/.config/opencode/
├── AGENTS.md                       # Global instructions + house style (loaded every session)
├── agents/<name>.md               # Agent definitions (selectable with --agent)
├── commands/<name>.md             # Slash commands (invocable with /<name>)
└── skills/<name>/SKILL.md          # Reference knowledge (loaded contextually)
```

**Pi Agent:**

```
~/.pi/agent/
├── AGENTS.md                       # Global instructions + house style (loaded every session)
├── agents/<name>.md                # Subagent definitions for pi-subagents
├── prompts/<name>.md               # Prompt templates (invocable with /<name>)
└── skills/<name>/SKILL.md          # Agent Skills (loaded contextually)
```

Pi Agent resources are rendered here and consumed by `../pi`, which owns the Pi package, runtime wrapper, settings, MCP adapter, subagent extension config, and theme files.

Agent, command, prompt, and skill files use Markdown with YAML frontmatter. Pi and Codex global instruction files are plain Markdown; Codex agent definitions are TOML. No agent pins a model on any platform except Garfield; every other agent inherits the model selected in the coding tool. OpenCode headers intentionally omit `model` on every agent, so users can switch Anthropic and OpenAI models manually. In frontmatter files, the prompt body follows the `---` delimiters. No build step is required - drop the files in and they work.

## Contents

- [Prompt Hierarchy](#prompt-hierarchy)
- [Global Instructions](#global-instructions)
- [Task Lifecycle](#task-lifecycle)
- [Agents](#agents)
- [Model Selection](#model-selection)
- [Platform Delivery](#platform-delivery)
- [Provider Routing](#provider-routing)

---

## Prompt Hierarchy

Instructions stack in four layers. Each layer narrows scope and increases specificity.

```
instructions/global.md          ← environment constraints, tool preferences, skill references
    └── AGENTS.md / CLAUDE.md   ← project-specific context, conventions, commands
            └── agent prompt    ← specialist persona, expertise, tools, constraints
                    └── command prompt  ← single task, may repeat the agent's model pin
```

**`instructions/global.md`** is the role-neutral foundation for every platform. It sets delegation triggers, fresh-context defaults, trust boundaries, reference-tool preferences, GitHub safety, LSP guidance, file rules, skill references, and verbatim relay. Full specialist routing and output contracts live in the generated `delegate-task` skill. See [`instructions/README.md`](instructions/README.md) for the research that informs the global rules and the generated skill.

Agent prompts inherit the global constraints and add specialisation. Command prompts inherit the agent context and focus on a single task - they stay short because the agent prompt already carries the persona, tools, and constraints. A command can set its own model header, but only Garfield's four commands do.

---

## Global Instructions

`instructions/global.md` has no persona. It tells the coordinator to use `delegate-task` before parent-thread exploration for non-trivial tool, file, research, implementation, review, validation, or documentation work.

### Agent Tripwire

`styles/house-style/house-style.md` is the canonical Communication Rules source. It carries no frontmatter, so every consumer reads the same body verbatim. Global instructions, agents, commands, and skills refer to the rules by name instead of carrying copied rule text.

Each platform takes the body through its own system-prompt channel:

| Platform    | Carrier                                                              |
| ----------- | -------------------------------------------------------------------- |
| Claude Code | Output style at `~/.claude/output-styles/house-style.md`, selected by `outputStyle = "house-style"` with `keep-coding-instructions: true` |
| Codex       | `developer_instructions` in `config.toml`, injected at the developer role; the built-in coding prompt is kept |
| OpenCode    | Appended to the global instructions in `AGENTS.md`                   |
| Pi Agent    | Appended to the global instructions in `AGENTS.md`                   |

`compose.nix` also generates the `communication-rules` skill from the same body, adding only the frontmatter that makes it discoverable. The skill stays for command-driven reinforcement and for surfaces with no system-prompt access, such as Codex Cloud. The `delegate-task` packet tells every sub-agent to load it.

The `hooks/communication-rules` mixin reads the style body directly and writes it to `~/.config/agent-communication-rules/communication-rules.md` with the shared scanner assets. Reminders, block messages, correction prompts, and runtime disclosures embed that body. Do not copy the rules into platform modules.

Agent Tripwire is not an agent bypass system. Blocked write, edit, post, and surfaced prose paths must be revised by the agent or stopped. Operator recovery stays outside the agent path: use the normal config disablement mechanism, such as `disableAllHooks`, or rebuild without the Agent Tripwire mixin when a false positive or broken hook needs human recovery.

### Session Priming

Every session begins with `/ready We are going to <broad activity description>`. This is a step-back prompt ([Zheng et al., 2023](https://arxiv.org/abs/2310.06117)) - an abstraction-first technique that weights the model's attention toward the relevant domain before specifics arrive. The description stays deliberately vague ("document my MCP configuration", not "write a README for the assistants directory") so the model activates broad domain knowledge rather than narrowing prematurely. Detailed instructions follow in subsequent messages once the model's attention is oriented.

### Context-Efficient Orchestration

Parent context is permanent and finite. Specialist context windows are ephemeral. Protect the parent window by using fresh context for file reads, code search, web research, implementation, audits, and other tool-heavy work. Fork only when the user explicitly requires it or when the parent transcript is essential.

When the coordinator lacks context, it delegates discovery instead of researching first. `delegate-task` owns routing, delegation depth, waiting and teardown, packet fields, the response contract, fresh-context rule, and relay policy. Nix work routes to Donatello with the `nix` skill.

### Response Discipline

The house style owns response discipline, every platform carries it in the system prompt, and the hooks enforce it. A single specialist output is relayed verbatim where the user cannot already see it, is never summarised in its place, and is intervened on only for safety.

### Standalone Commands

| Command                 | Purpose                                                               |
| ----------------------- | --------------------------------------------------------------------- |
| `ack`                   | Acknowledge a phase or message and yield                              |
| `ahem`                  | Re-issue the Communication Rules as a first warning                   |
| `ask`                   | Answer a question without treating it as an instruction              |
| `call`                  | Give one recommended solution with its reasoning, never a menu        |
| `collaborate`           | Read a task or file, meet the team, and prepare to collaborate         |
| `gist`                  | Rewrite the previous response concisely                               |
| `grill-me`              | Interview the user until every branch of a design is resolved         |
| `implement-task`        | Take a tracked task through to implemented, validated, committed work |
| `oi`                    | Re-issue the Communication Rules bluntly, after `ahem` failed         |
| `orientate`             | Inspect the repository and report orientation notes                   |
| `ready`                 | Prime the session for a broad activity                                |
| `reflect`               | Review the session and suggest tooling and AGENTS.md changes          |
| `review-code-colleague` | Review a colleague's PR for defects only; no suggestions, no nits     |
| `review-code-community` | Review a community PR for correctness, gaps, and malicious code       |
| `review-code-mine`      | Adversarially review my own changes before filing a PR                |
| `wtb`                   | Run the Want to Buy workflow for a pull request and Slack channel     |

---

## Task Lifecycle

Four commands and one skill share one noun. The vocabulary is strict:

- **Task** - a durable, tracked work item: a Linear issue, or a local markdown file.
- **Plan** - ephemeral, and outside any project tree.
- **Phase** - a unit of work inside a plan.

| Step | Capability       | Form    | Purpose                                                                  |
| ---- | ---------------- | ------- | ------------------------------------------------------------------------ |
| 1    | `create-task`    | Command | File the session outcome as a task, or a parent wrapping children        |
| 2    | `research-task`  | Skill   | Research a task and its linked work, and synthesise one cited analysis   |
| 3    | `update-task`    | Command | Fold session decisions into the task so it stays the source of truth     |
| 4    | `review-task`    | Command | Judge whether a task is ready to implement, and what must change first   |
| 5    | `implement-task` | Command | Take the task through to implemented, validated, committed work          |

`create-plan` writes to `${TMPDIR:-/tmp}/agent-plans/<key>-<slug>/plan.md`, outside any project tree. A plan exists only while one task is implemented. It is never committed and is discarded afterwards. The durable record is the task, not the plan.

The `create-project` command and `draft-project-description` skill write the project the tasks live in, and sit outside the lifecycle. They take a project, not a task, so they carry no step number and no place in the run order.

### Orchestration

`triage-tasks` orchestrates steps 2 and 3 over the Triage queue, so it carries no step number of its own. It finds the Linear issues waiting in Triage, reports the batch, then spawns one fresh sub-agent per issue that applies the `research-task` skill and then runs `update-task` in a single context. `update-task` promotes each issue to Backlog, so the queue clears itself and a re-run picks up only what is new or what failed.

`implement-task` orchestrates and never implements. It accepts a single task, or a parent task wrapping children, and takes the run order from the parent's dependency-ordered `Child issues` list. The user-invoked command is the sole dispatcher: it launches one fresh planning worker per task, then one fresh implementation worker per phase in dependency order. Every worker returns directly to the command and never launches another agent.

Validation is inline. Each task's changed files are checked against the task's `Acceptance criteria` before that task is committed.

`implement-task` opens one branch named from the Linear issue's `gitBranchName`, commits once per task with a `Refs: <ISSUE-KEY>` footer, and stops. It never opens or drafts a pull request; run `make-pr` yourself. Linear keys its auto-close on the branch name when the pull request is eventually merged.

---

## Agents

### Rosey - Prompt & Skill Specialist

Prompt and skill specialist for agent prompts, skills, commands, and instruction files. Rosey edits these artefacts directly, applies context-efficiency constraints, and keeps prompt guidance short enough to hold. She is not the global coordinator; `instructions/global.md` owns default delegation policy. See [`agents/rosey/README.md`](agents/rosey/README.md) for the research that informs Rosey's prompt, skills, and command shims.

**Model:** inherits the model selected in the coding tool on every platform.

Rosey's prompt engineering rules:

- Imperatives over explanations - "Focus on X" not "You should focus on X"
- Constraints over descriptions - say what to do and not do
- Decision criteria over vague terms - "files changed in last 5 commits" not "recently modified"
- Examples only when essential - subjective style, judgment calls, complex formats

Prompt constraints:

- 500-800 tokens per agent prompt, 1,200 max for prompts with examples
- OpenCode direct startup should stay near the measured floor: about 15K tokens with MCPs disabled
- `/ready` should stay close to direct startup, about 16K today, without eager-loading `delegate-task`
- Delegated sessions around 17K-18K are acceptable today because loading `delegate-task` adds about 2K tokens

The older under-10K target remains useful as compliance evidence, not as the OpenCode startup baseline. The controllable costs discussed so far are repo `AGENTS.md` at about 1.7K tokens, `instructions/global.md` at about 0.6K, and generated `delegate-task` at about +2K. Context7 and Exa MCPs stay enabled in the normal setup; the quoted baseline excludes MCPs to isolate assistant and repo guidance. Reduce `delegate-task` and always-listed skill or agent metadata before chasing a 10K total that the platform floor already exceeds.

Compact, stable system prompts preserve Claude prompt-cache hits; bloated or variable prompt prefixes defeat caching. Rosey's `update-assistant` command removes ineffective patterns while preserving output templates, few-shot examples, decision criteria, explicit constraints, tool-specific guidance, and numeric limits.

| Command            | Purpose                                                           |
| ------------------ | ----------------------------------------------------------------- |
| `create-assistant` | Generate a new agent prompt from requirements                     |
| `create-agents-md` | Create `AGENTS.md` from codebase analysis                         |
| `create-skill`     | Create a reusable `SKILL.md`                                      |
| `create-command`   | Create a slash command (shim or standalone)                       |
| `update-assistant` | Apply context-efficiency pass to an existing agent                |
| `update-agents-md` | Apply targeted changes or consolidate scattered instruction files |
| `update-skill`     | Improve an existing reusable skill                                |
| `update-command`   | Update an existing slash command and its provider headers         |
| `handover-fresh`   | Write structured handover document for a new session              |
| `handover-fork`    | Fork-compact briefing for an in-session specialist subagent       |

---

### Batfink - Infrastructure Security Auditor

Infrastructure security auditor assessing configuration hardening, defensive resilience, and blast radius across cloud, container, and network infrastructure. Identifies misconfigurations, privilege escalation paths, and lateral movement risks. Every finding is mapped to concrete remediation.

**Model:** inherits the model selected in the coding tool on every platform. Infrastructure security assessment reasons across interacting systems, trust boundaries, and attack chains simultaneously.

| Command                | Purpose                                  |
| ---------------------- | ---------------------------------------- |
| `audit-infra-security` | Structured infrastructure security audit |

---

### Brain - Test Engineer

Pragmatic test engineer identifying high-impact unit tests that catch real bugs. Analyses git history to find frequently-fixed files, searches GitHub issues for bug patterns, and reads existing tests before recommending new ones. Focuses on coverage gaps that matter rather than coverage numbers.

**Model:** inherits the model selected in the coding tool on every platform.

| Command                | Purpose                                        |
| ---------------------- | ---------------------------------------------- |
| `project-tests-review` | Analyse codebase for high-value test additions |

---

### Casper - Technical Writer

Ghost writer emulating Martin Wimpress's blog voice: enthusiastic, conversational British English combining Linux expertise with accessible humour. First-person narrative, direct reader address, British colloquialisms integrated naturally. Loads `writing-well` for extended writing.

**Model:** inherits the model selected in the coding tool on every platform.

| Command              | Purpose                                |
| -------------------- | -------------------------------------- |
| `draft-blog-post`    | Write a blog post in Martin's voice    |
| `draft-video-script` | Write a video script in Martin's voice |

---

### Dibble - Code Security Auditor

Code security auditor methodically patrolling codebases for vulnerabilities, insecure patterns, and dependency risks. Cites CWE and OWASP classifications for every finding. Distinguishes confirmed vulnerabilities from theoretical risks and prioritises by exploitability.

**Model:** inherits the model selected in the coding tool on every platform. Vulnerability identification reasons across data flows, trust boundaries, and exploitation conditions.

| Command               | Purpose                        |
| --------------------- | ------------------------------ |
| `audit-code-security` | Structured code security audit |

---

### Donatello - Implementation Engineer

Precise implementation engineer executing code changes from specifications. Reads related files before any implementation, reuses existing utilities before writing new ones, identifies blockers early. Preserves existing conventions and architectural decisions. Loads the `nix` skill for Nix, NixOS, Home Manager, nix-darwin, flakes, packages, modules, and `.nix` files. Loads the `love` skill for LÖVE 2D and Lua 5.1/LuaJIT 2.1 game development.

**Model:** inherits the model selected in the coding tool on every platform.

| Command                   | Purpose                                                            |
| ------------------------- | ------------------------------------------------------------------ |
| `create-plan`             | Break implementation into ordered phases in a disposable plan      |
| `implement-plan`          | Execute a plan, one fresh sub-agent per phase                      |
| `draft-code-review`       | Draft the house-style review comment from a completed review       |
| `post-code-review`        | Post the review comment and set the verdict on GitHub              |
| `address-code-review`     | Work review findings one at a time, committing each fix            |
| `pr-watch`                | Watch a PR: fix CI failures, triage flakes, answer reviews         |
| `project-peer-review`     | Give an ecosystem-specific codebase verdict                        |
| `project-polish-comments` | Comment-quality pass over a file set; comments only, never logic   |
| `add-agentic-repo-capability` | Add a repository-local MCP server, skill, or command across clients |
| `add-enricher-capability` | Add a manifest-gen enricher capability                             |

---

### Garfield - Git Workflow Specialist

Git workflow specialist enforcing Conventional Commits 1.0.0. Analyses existing commit history for project-specific scope patterns before writing messages. Handles type classification, scope determination, and breaking change footers.

**Model:** the only pinned agent in the tree. Claude Code takes `model: sonnet` on the agent and on all four commands. Pi takes `claude-sonnet-5` on the Anthropic route, `gpt-5.6-terra` at thinking `medium` on the OpenAI route, and `gemini-3-flash` on Google. Codex takes `gpt-5.6-terra` at reasoning `medium`. Commit message generation is a structured, deterministic task with clear rules, so it does not need the session's reasoning budget.

| Command                | Purpose                                                                                                                                  |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `draft-commit-message` | Draft a conventional commit message for the staged or current changes                                                                    |
| `draft-pr-message`     | Draft a conventional commit message summarising the branch for a PR body                                                                 |
| `make-commit`          | Draft the message, then create one commit from the durable work                                                                          |
| `make-pr`              | Draft the title and body, open the PR, move Linear to In Review, and on a work PR request the work review team and apply `ai-review`     |
| `pr-done`              | Update main, drop the worktree and branch, move Linear to Done                                                                           |

---

### Gonzales - Performance Specialist

Performance optimisation specialist focused on user-perceivable improvements. Rates optimisations on a 1-10 impact scale. Only recommends changes where the user-perceivable effect justifies the maintainability cost.

**Model:** inherits the model selected in the coding tool on every platform. Separating true bottlenecks from theoretical micro-optimisations reasons across algorithmic complexity, memory patterns, and I/O behaviour simultaneously.

| Command                      | Purpose                                                 |
| ---------------------------- | ------------------------------------------------------- |
| `project-performance-review` | Identify optimisation opportunities with impact ratings |

---

### Penfold - Research Generalist

Research partner for exploring ideas, generating options, and framing problems for downstream specialists. Penfold owns the task lifecycle commands that file session outcomes, fold decisions back into tasks, triage the queue, and judge implementation readiness. Flags uncertainty explicitly (confidence: high/medium/low). Produces handoffs specialists can use without clarification. Loads the `audio-metrics` skill for objective audio analysis from ffmpeg metrics: spectral statistics, loudness (EBU R128, LUFS, true peak), levels, and spectrograms.

**Model:** inherits the model selected in the coding tool on every platform. Penfold synthesises research, frames problems, and weighs trade-offs; specialist agents still handle domain-specific validation.

| Command                     | Purpose                                                                 |
| --------------------------- | ----------------------------------------------------------------------- |
| `create-task`               | File the session outcome as a task, or a parent wrapping children       |
| `update-task`               | Fold session decisions into an existing task                            |
| `triage-tasks`              | Research and update the Linear issues waiting in Triage, in bulk        |
| `review-task`               | Judge whether a task is ready to implement, and what must change first  |
| `create-project`            | Find or create one Linear project, and stop                             |
| `post-comment`              | Post the agreed comment to GitHub, Linear, or Slack                     |
| `post-issue`                | Create the agreed issue on GitHub                                       |
| `weekly-update`             | Write this week's Linear project updates, and point at them in Slack    |
| `gather-review-data`        | Collect the user's own contribution evidence for a date range           |
| `draft-self-review`         | Draft a periodic self-review from gathered evidence                     |

---

### Penry - Code Reviewer

Maintainability specialist reviewing for simplification, duplication, dead code, and naming clarity. Every suggestion is small, safe, and preserves exact functionality. Uses an impact scale; only flags changes where the maintainability benefit justifies the diff.

**Model:** inherits the model selected in the coding tool on every platform.

| Command                     | Purpose                                                       |
| --------------------------- | ------------------------------------------------------------- |
| `project-code-review`       | Maintainability review: deletion, replacement, simplification |
| `project-smells-review`     | Hunt for genuine code smells: god objects, feature envy, etc. |
| `audit-communication-rules` | Validate the Communication Rules tripwire hooks end to end    |

---

### Velma - Documentation Architect

Documentation architect creating technically precise guides through progressive disclosure. Transforms codebases into accessible documentation. Loads `writing-well` for extended writing tasks.

**Model:** inherits the model selected in the coding tool on every platform. Documentation writing is a structured task where voice, clarity, and organisation carry the result.

| Command                        | Purpose                                                     |
| ------------------------------ | ----------------------------------------------------------- |
| `draft-readme`                 | Write README following standard structure                   |
| `align-documentation`          | Update documentation to reflect code changes                |
| `project-documentation-review` | Audit documentation, identify gaps, prioritise improvements |

---

## Model Selection

Agents follow the model selected in the coding tool. Martin picks a model once per session and every specialist he delegates to runs on it, so there is one decision to make and no per-agent tier to remember. Claude Code, OpenCode, Codex, and Pi all behave the same way: with no `model` in the header, the agent inherits the session model.

Garfield is the sole exception. Commit and PR message work is structured and deterministic, so it does not need the session's reasoning budget:

| Platform            | Pin                                                |
| ------------------- | -------------------------------------------------- |
| Claude Code         | `model: sonnet` on the agent and all four commands |
| Pi (Anthropic)      | `claude-sonnet-5`                                  |
| Pi (`openai-codex`) | `gpt-5.6-terra`, thinking `medium`                 |
| Pi (Google)         | `gemini-3-flash`                                   |
| Codex               | `gpt-5.6-terra`, reasoning `medium`                |

No other agent or command sets a model on any platform. The ten remaining agents have no `header.pi.yaml` and no `header.codex.toml` at all, and their `header.claude.yaml` omits `model`.

**Command-level model pins:** only Garfield's four commands set one. `draft-commit-message`, `draft-pr-message`, `make-commit`, and `make-pr` each repeat `model: sonnet` in Claude Code so the pin holds when the command runs outside the agent. No other command in the tree sets a model.

---

## Platform Delivery

`compose.nix` reads the source tree and generates platform-specific output. Each agent has one `prompt.md` and optional per-platform headers: `header.claude.yaml`, `header.opencode.yaml`, `header.codex.toml`, and `header.pi.yaml`. Only Garfield carries the Codex and Pi headers today. Codex agents use `header.codex.toml` for role-local config, and Codex command skills can use `header.codex.toml` with `spawn-agent = true` to delegate through `spawn_agent`.

Pi composition routes through `compose.composeAgentFromPrompt "pi"` and `compose.composeCommand "pi"`. The agent-scoped command prelude ("Use the subagent tool to launch the `<agent>` agent...") is assembled in `default.nix` and wraps `compose.composePiCommandFromPrompt`, mirroring how the Codex side wraps `spawn_agent` guidance around skill bodies.

`header.pi.yaml` is optional. When absent, Pi subagents inherit three generated defaults: `systemPromptMode: append`, `inheritProjectContext: false`, and `inheritSkills: true`. The header file may carry any Pi-native frontmatter field: `model`, `thinking`, `tools`, `defaultContext`, `output`, `fallbackModels`, `maxSubagentDepth`, plus per-command `argument-hint`. Fields present in the file are appended verbatim, so explicit per-agent depth limits are preserved.

OpenCode `permission` headers are not mapped to Pi. Pi supports an explicit `tools` allowlist for subagents, but OpenCode's allow/deny permission model is not equivalent.

### Provider routing

Pi can route a subagent to a provider-specific model and/or reasoning effort
through extra `model-<provider>` and `thinking-<provider>` keys in the agent's
`header.pi.yaml`:

```yaml
model-anthropic: claude-sonnet-5
model-openai-codex: gpt-5.6-terra
model-google: 'gemini-3-flash'
thinking-openai-codex: medium
```

That is Garfield's live header, quoted verbatim. He is the only agent with a
`header.pi.yaml`, so he is the only agent the router matches.

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

This repo's convention is **no headers by default**. Only Garfield declares
`model-<provider>` and `thinking-<provider>` keys; every other agent ships
without a `header.pi.yaml` and inherits the model selected in the session. Any
agent that does need a pin should declare `model-anthropic`,
`model-openai-codex`, and `thinking-openai-codex` together, so the active model
and reasoning effort are readable from the agent's own header. Additional
providers (e.g. `model-google`) are added per-agent where relevant. The router
also supports thinking-only entries, where the runtime reuses the active
session model id.

Pi's global `defaultThinkingLevel = "medium"` and `defaultModel = "gpt-5.6-sol"`
set the session default for the unnamed global prompt. Agents that omit a
header do not fall back to them per-agent; they inherit whatever model the
session is running.

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
| Claude Code | `~/.claude/agents/*.md`                | `~/.claude/commands/*.md`                 | `~/.claude/rules/instructions.md` | `~/.claude/skills/*/SKILL.md`          |
| OpenCode    | `~/.config/opencode/agents/*.md`       | `~/.config/opencode/commands/*.md`        | `~/.config/opencode/AGENTS.md`    | `~/.config/opencode/skills/*/SKILL.md` |
| Codex       | `~/.config/codex/agents/*.toml`        | `~/.config/codex/skills/*/SKILL.md`       | `~/.config/codex/AGENTS.md`       | `~/.config/codex/skills/*/SKILL.md`    |
| Pi Agent    | `~/.pi/agent/agents/*.md`              | `~/.pi/agent/prompts/*.md`                | `~/.pi/agent/AGENTS.md`           | `~/.pi/agent/skills/*/SKILL.md`        |

### Secret prompts

A few command and skill bodies must not enter git or the Nix store. Those directories ship a marker file instead of the plaintext: `prompt.sops` for a command, `SKILL.sops` for a skill. The marker holds one thing, the name of a top-level key in `secrets/assistant-prompts.yaml` whose value is the body. A secret skill's supporting files follow the same convention under the general rule that any `<name>.sops` marker renders to `<name>`, so `references/cycle-mechanics.md.sops` renders to `references/cycle-mechanics.md`; `SKILL.sops` and `prompt.sops` are the two fixed, named exceptions to that rule.

`compose.nix` detects the marker and composes the file with a sops placeholder where the body would go. Claude Code, OpenCode, and Pi receive a sops template that sops-nix renders at activation. Codex gets an activation script that appends the decrypted body, because the Codex skill step clears its own output directory first. Either way the plaintext lives only in the activated file, never in the store.

A directory holding both the marker and its plaintext counterpart fails evaluation, so the two can never drift apart.

`description.txt` and the `header.*.yaml` files stay plaintext and are composed normally. Keep them free of whatever the encrypted body protects.

### Skills

Shared skills provide background knowledge and reference material. Most are sourced from `skills/*/SKILL.md`. Two are generated, so their content cannot drift from its source: `delegate-task` from the agent registry, and `communication-rules` from the house style body. A static skill directory with either name is ignored.

**Generated and agent-loaded:**

| Skill                | Loaded by                 | Purpose                                                                                                           |
| -------------------- | ------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `delegate-task`      | Coordinator or user       | Generated routing, depth, waiting, teardown, packet, response contract, and relay policy                          |
| `communication-rules` | Every prose-producing path | Generated from the house style: concise, plain British English for user-visible prose                             |
| `agentic-repo-capability` | Donatello or user         | Add a repository-local MCP server, skill, or command across supported agent clients                               |
| `writing-well`       | Casper, Velma             | Composition principles and the AI writing-pattern catalogue                                                       |
| `write-skill`        | Rosey or user             | Author or update an Agent Skill (`SKILL.md`) - frontmatter, layout, references, progressive disclosure            |
| `write-agents-md`    | Rosey or user             | Author, update, or consolidate AGENTS.md / CLAUDE.md / .cursorrules project instruction files                     |
| `write-assistant`    | Rosey or user             | Author or update an agent system prompt - persona, structure, voice, examples, constraints                        |
| `write-command`      | Rosey or user             | Author or update a slash command - shim or standalone, headers per provider, argument-hint, model                 |
| `review-report-path` | Review and audit commands | The `${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/` path and the slug rules for concurrent reviews            |
| `sizing`             | Task and review commands  | T-shirt sizing scale, spikes, parent tracking issues, and splitting oversized work                                |
| `nix`                | Donatello                 | Nix, NixOS, Home Manager, nix-darwin, flakes, packages, modules, registries                                       |
| `love`               | Donatello                 | LÖVE 2D, LÖVE engine, `love2d`, `.love` archives, Lua 5.1/LuaJIT 2.1 game work                                    |
| `audio-metrics`      | Penfold or user           | Objective definitions of ffmpeg audio metrics: aspectralstats, astats, ebur128, loudnorm, plus loudness standards |
| `self-review`        | Penfold or user           | Structure and checklist for a periodic self-review                                                                |
| `how-to-contribute`  | Penfold or user           | Assess a project's contribution rules before an issue or pull request                                             |

**User-invocable support skills:**

| Skill                | Purpose                                                                   |
| -------------------- | ------------------------------------------------------------------------- |
| `contribution-voice` | Structure rules for text published under the user's name in public        |
| `deep-research`      | Multi-round research on an open question, synthesised into a cited report |
| `research-task`      | Research an existing tracked task and its linked work into a cited report |
| `draft-project-description` | Write a Linear project description in the form the quality coach scores   |
| `draft-comment`      | Read-only drafting for GitHub, Linear, or Slack comments and replies      |
| `draft-issue`        | Read-only GitHub issue drafting with policy and duplicate checks          |
| `gh`                 | GitHub CLI reference - PR creation, issue management, releases            |
| `review-code`        | Shared review method: input resolution, fan-out, pressure-test, report    |
| `semgrep`            | Semgrep CLI usage and custom rule creation reference                      |
| `slack`              | Slack reference - `slack-post` target forms, channel resolution, threads  |
