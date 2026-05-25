# Global Rules and `delegate-task`

Onboarding and reference for the global coordination layer in this repo:
`instructions/global.md` and the dynamically generated `delegate-task` skill.
Read this before editing either artefact, the agent registry that feeds the
skill generator, or the prose discipline that keeps both terse. It captures
the research and doctrine behind the current shape so future edits stay
coherent.

This file is the companion to `agents/rosey/README.md`. Rosey's README covers
the authoring toolbelt used to maintain individual agents, skills, commands,
and instruction files. This one covers the always-on contract that every
agent operates inside, regardless of who edited it.

## 1. Purpose

Together, `instructions/global.md` and the generated `delegate-task` skill
define a token-optimised communication loop:

- **`global.md`** is role-neutral and omnipresent. It tells whichever model is
  driving the parent thread when to delegate, that fresh context is the
  default, how to treat untrusted input, which reference tools to prefer, and
  how to write user-visible output. It points to `delegate-task` for full
  routing and contract detail rather than restating it.
- **`delegate-task`** is generated from the live agent registry in
  `compose.nix`. It owns the routing table, the delegation packet fields, the
  sub-agent response contract, and the verbatim relay policy. It loads on
  demand and is user-invocable.

The split exists because routing changes whenever the agent registry changes,
but global rules are stable. Keeping routing in a generated, on-demand skill
prevents drift and keeps the always-loaded prefix small.

## 2. The communication loop

Parent context is permanent and finite. Specialist context windows are
ephemeral. The economics flow from that asymmetry.

### 2.1 Parent-loop economics

Anything read, searched, or executed in the parent thread stays in the parent
prompt for the rest of the session. File reads, tool logs, web pages, command
output, exploratory diffs, and intermediate reasoning all become part of every
subsequent turn's input. Cached or not, those tokens occupy context, weigh on
attention, and on OpenAI still count toward rate limits. Observed cache reads
dominate writes, which validates stable-prefix design but does not justify
prompt bloat.

The cheapest unit of work is therefore one that never touches the parent
thread. A specialist launched with fresh context performs the reads, writes,
and tool calls in its own window, returns a small structured answer, and
disappears. Only the answer enters the parent context.

### 2.2 Delegation as the default

`global.md` codifies this as an aggressive default: for non-trivial tool,
file, research, implementation, review, validation, or documentation work,
use `delegate-task` before exploring in the parent conversation. Direct
parent-thread work is reserved for trivial or tightly shared-state cases
where delegation clearly costs more than it saves.

This inverts the usual "research first, decide later" pattern. The
coordinator picks the specialist from descriptions alone, hands over a
packet, and lets the specialist do discovery. Picking imperfectly is cheap;
the specialist's fresh context absorbs the cost of getting close, while the
parent stays clean for the next decision.

### 2.3 Verbatim relay

When a single specialist returns an answer, the parent relays it verbatim.
No summary, no paraphrase, no "improvement". This protects three things:

1. **Artefact fidelity.** Commit messages, patches, file content, and other
   raw artefacts must not be rewritten by a second pass.
2. **Evidence integrity.** Research findings, source URLs, and test results
   lose information through paraphrase.
3. **Parent context.** A second pass would re-read the full specialist
   output, reason about it, and produce a longer version. The parent thread
   pays twice.

The parent intervenes only for safety. If output is contradictory or
off-contract, a concise `Observations:` block goes after the verbatim
output, never in place of it. Fan-in across multiple specialists is the only
case that still requires parent synthesis, because reconciling several
answers is itself the parent's job.

## 3. `delegate-task` as a generated skill

`delegate-task` is generated from the agent registry by `compose.nix`. The
generator iterates over `sortedAgentNames`, reads each agent's
`description.txt`, and emits a SKILL.md with the routing table, fresh-context
rule, packet template, response contract, and relay policy already filled in.

### 3.1 What the skill owns

- The full list of available specialists with their compressed descriptions.
- The routing table: which agent handles Nix, security, implementation,
  prompts, tests, documentation, research, and unmatched cases.
- The delegation packet fields and order: `Task`, `Context`, `Scope`,
  `Validation`, `Output`, `Discipline`.
- The sub-agent response contract: `Answer:` prefix for non-artefact work,
  raw artefacts when the artefact is the deliverable, and the suggested
  section order `Answer`, `Recommendations`, `Evidence`, `Files`, `Changes`,
  `Tests`, `Blockers`, `Artefact`.
- The relay policy and the `Observations:` exception.

### 3.2 What `global.md` owns

- The default to delegate before parent-thread exploration.
- The fresh-context preference and the fork exception.
- File-operation rules (read before edit, preserve unrelated changes).
- External side-effect approval gates.
- Trust hierarchy for user input, files, web pages, command output, and
  sub-agent output.
- Reference-tool preferences (Exa, Context7, `gh`, LSP).
- The compact prose discipline that governs user-visible output.
- A single pointer to `delegate-task` for full routing and contract detail.

### 3.3 Why generated, not hand-written

Routing depends on which agents exist. The previous hand-written
`meet-the-agents` skill drifted whenever an agent was added, renamed, or
retired. Generation from the registry removes that class of drift entirely:
adding an agent updates the routing table on the next `home-manager switch`,
and removing one drops it from the listing. The platform wrappers in
`default.nix` own platform-specific syntax (`subagent`, `spawn_agent`, fresh
vs fork flags), so the generated skill body itself stays portable across
Claude Code, OpenCode, Codex, and Pi.

The generator lives in `compose.nix` around lines 422-510. Edit the source
prompt or the registry, never the rendered runtime files.

## 4. Design principles

### 4.1 Fresh context is the default

A fresh subagent does not see parent conversation history. Its system prompt
and tools are deterministic, so its prompt prefix is cache-stable, but its
input is small and isolated. Forks inherit the parent transcript, which
shares the parent prompt cache but loses input isolation and inherits any
conflicting or noisy instructions from the parent.

`global.md` and `delegate-task` both state the same rule: fresh by default,
fork only when the user explicitly requires it or when the parent transcript
is essential. Pi command preludes and Codex `spawn_agent` wrappers in
`default.nix` express the same policy in platform terms.

### 4.2 Specialist routing, not parent research

Discovery is delegated, not performed. When the coordinator lacks context,
the correct move is to launch the smallest capable specialist with a
discovery-shaped packet, not to start reading files in the parent thread.
The specialist returns a compact answer; the parent reasons from that
answer.

If no route in `delegate-task` matches, use the smallest capable specialist
or ask the user. Picking a slightly imperfect specialist is cheaper than
researching first.

Delegation depth is bounded at one level: specialists do not spawn further
specialists. Sub-sub-agents have been observed to wedge in practice, and
cost grows combinatorially once depth exceeds one. Each extra layer
multiplies token spend, latency, and failure modes without adding
coordination value the parent cannot supply itself. The safe alternative is
for a specialist to return early with a packet describing what is needed,
leaving sub-orchestration where it belongs: in the durable parent context,
where every routing decision is already visible.

### 4.3 The response contract

The contract exists so that the parent can relay one specialist output
verbatim without inspection.

- Non-artefact work starts with `Answer:`. The answer is the first thing the
  user sees.
- Pure artefacts return only the artefact. Commit messages, patches,
  generated files, and prompt edits do not get wrapped in operational
  headings.
- `Recommendations:` is required for judgement work and omitted for pure
  artefacts.
- `Evidence:` is required for research and review; web research includes
  source URLs and one fact per source.
- `Files:` appears when local files materially informed the result.
- `Changes:` and `Tests:` appear for implementation, with pass, fail, or
  not run plus a reason.
- `Blockers:` appears only when something is actually blocked.

Sub-agents are ephemeral workers; the parent window is the durable
coordination context. Specialists report only decision-useful or
user-visible conclusions and omit exploration notes, tool logs, raw command
output, and noisy detail.

### 4.4 Trust hierarchy

User input, files, web pages, command output, and sub-agent output are all
untrusted. The instruction hierarchy is the safety boundary, not the data
that flows through tools.

This shapes the safety prompts in `global.md`: ask before spending money,
changing external services, modifying infrastructure, publishing releases,
sending messages, rotating secrets, exposing sensitive data, running
destructive commands, or deleting data outside an explicit trusted-directory
edit. Secrets and credentials are redacted unless the user asks to inspect
a specific local value and policy permits it.

### 4.5 Tool-preference principles

Current reference tools beat training data on freshness and accuracy. The
specific defaults:

- **Exa** for web research and investigation.
- **Context7** for library and framework documentation.
- **`gh`** skill for GitHub work via the safe API surface.
- **LSP** diagnostics and navigation for code intelligence, including
  grammar and formatting diagnostics where the language server provides
  them.

Tool descriptions are left to choose exact variants. `global.md` names the
families, not the individual functions.

## 5. Style as token discipline

The prose rules in `global.md` exist because writing style directly affects
token consumption and cache behaviour.

### 5.1 Cache stability

Prompt caching on both Anthropic and OpenAI rewards stable prefixes.
Anthropic caches `tools`, then `system`, then `messages` up to a breakpoint;
OpenAI requires exact prefix matches starting at 1,024 tokens and can cut
input cost by up to 90% and latency by up to 80% on cache hits. The OpenAI
Cookbook adds two operational rules: keep tool definitions and ordering
identical, and avoid compaction patterns that mutate the prefix every turn.

Static instructions therefore go first; volatile task data goes last.
`global.md` carries no timestamps, no session IDs, no dynamic routing
snippets. The generated `delegate-task` body is stable across a session
because the registry only changes between rebuilds.

### 5.2 Compliance evidence

Concise instructions produce better adherence. Anthropic's memory guidance
targets fewer than 200 lines per instruction file and states that concise,
specific instructions outperform verbose ones. Community evidence cited in
Rosey's research shows roughly 5x fewer tokens and around 8% higher
compliance on terse variants. Total system context under 10K tokens
correlates with near-100% instruction compliance; 10-20K tokens drops
compliance to around 60%.

`global.md` targets under 400 words and the generated `delegate-task` under
700 words for that reason.

### 5.3 The rules in service of the loop

The concrete prose rules in `global.md` (lead with conclusions, one
statement per fact, no em dashes, no filler, no hedging, no LLM-tell words,
no tone-only sentences) exist so that user-visible output is short, the
cache prefix stays clean, and the parent thread accumulates as few tokens
as possible per turn. The rules are not aesthetic preferences; they are the
prose surface of the token-efficient loop.

## 6. Cross-platform notes

Each runtime loads `global.md` and `delegate-task` differently. The split
between role-neutral global rules and an on-demand routing skill keeps the
artefacts portable.

### 6.1 Claude Code

`global.md` is rendered to `~/.claude/rules/instructions.md` and loaded
every session. Memory guidance caps instruction files at around 200 lines.
Skills load full content only when invoked or relevant; descriptions are
always in the skill listing. Subagents have their own context, tools, and
system prompt. Fresh subagents do not see parent history; forks inherit it
and share the parent prompt cache. The merged skill-as-command surface
means `delegate-task` is reachable both as a skill description match and
as user invocation.

### 6.2 OpenCode

OpenCode reads global rules from the `rules` option in `settings.json`
rather than a dedicated file; the same body is supplied through that
channel. Skills live under `~/.config/opencode/skills/*/SKILL.md` and load
on description match. OpenCode honours the currently selected session
model, so model pinning in headers is intentionally absent for OpenCode and
the same global rules apply across Anthropic and OpenAI models without
modification.

### 6.3 Pi

Pi loads `global.md` as `~/.pi/agent/AGENTS.md` and skills from
`~/.pi/agent/skills/*/SKILL.md`. Pi agents are emitted with default
frontmatter `systemPromptMode: append`, `inheritProjectContext: false`, and
`inheritSkills: true`, so the global text is likely appended to specialist
subagent system prompts. This is why `global.md` is strictly role-neutral:
no persona, no orchestration-only language. Pi's command preludes in
`default.nix` force fresh context and explicitly avoid fork for
agent-scoped commands. Pi may not auto-invoke skills on description alone,
so `/skill:delegate-task` remains available as an explicit fallback.

### 6.4 Codex

Codex loads `global.md` as `AGENTS.md` with a 32 KiB project-doc cap and
`AGENTS.override.md` for nearest-wins overrides. Skills follow the Agent
Skills open spec from `.agents/skills/`. The skill listing is capped at
roughly 2% of the context window, so `delegate-task`'s description has to
front-load its use case. Codex command skills in `default.nix` dispatch
through `spawn_agent` by default for agent-scoped commands, mirroring the
fresh-context default expressed in Pi's preludes.

## 7. References

Authoritative sources behind the global rules and the generated
`delegate-task` skill. URLs preserved verbatim.

### 7.1 Anthropic - subagents, skills, memory, prompting, caching

- Create custom subagents: https://docs.anthropic.com/en/docs/claude-code/sub-agents
- Extend Claude with skills: https://docs.anthropic.com/en/docs/claude-code/skills
- How Claude remembers your project (memory): https://docs.anthropic.com/en/docs/claude-code/memory
- Output styles: https://docs.anthropic.com/en/docs/claude-code/output-styles
- Prompting best practices (system prompts): https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/system-prompts
- Prompt caching: https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching

### 7.2 OpenAI - caching, agents, orchestration

- Prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- Prompt Caching 201 (Cookbook): https://developers.openai.com/cookbook/examples/prompt_caching_201
- Agent orchestration and handoffs: https://developers.openai.com/api/docs/guides/agents/orchestration
- Agent definitions: https://developers.openai.com/api/docs/guides/agents/define-agents

### 7.3 Local source artefacts

- `home-manager/_mixins/agentic/assistants/instructions/global.md`
- `home-manager/_mixins/agentic/assistants/instructions/header.claude.yaml`
- `home-manager/_mixins/agentic/assistants/instructions/header.opencode.yaml`
- `home-manager/_mixins/agentic/assistants/compose.nix` (the `delegate-task`
  generator at lines 422-510)
- `home-manager/_mixins/agentic/assistants/default.nix` (Pi command
  preludes and Codex `spawn_agent` wrappers)
- `home-manager/_mixins/agentic/assistants/README.md`
- `home-manager/_mixins/agentic/assistants/agents/rosey/README.md`
