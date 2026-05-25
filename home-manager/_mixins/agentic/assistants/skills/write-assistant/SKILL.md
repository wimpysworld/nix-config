---
name: write-assistant
description: Use when creating, updating, refactoring, or reviewing an AI assistant or sub-agent system prompt - persona, role, capabilities, tools, output format, examples, and constraints. Covers Claude Code agents, OpenAI Codex / Responses-API agents, Pi assistants, and OpenCode agents. Use even if the user only says "agent prompt", "assistant", "subagent", "persona", or names the artefact by file path.
---

# Write Assistant

Author and maintain agent system prompts: the always-loaded persona, capabilities, and constraints that define a sub-agent. One artefact, two flows: create from requirements or update in place.

## Decide first

- **Create** vs **update** vs **split**. Split an agent when one prompt mixes different tools, guardrails, models, or output styles that diverge in practice.
- **Examples** vs **no examples**. Add 1-2 examples for subjective style or judgment work; omit for procedural agents.
- **Triggers** vs **direct invocation**. Sub-agents selected by routing need a trigger-rich `description`; user-invoked agents only need a name.

## Required structure

```markdown
---
name: <agent-name>
description: <one-sentence trigger summary>
---

# <Name> - <Role>

## Role & Approach

<2-4 sentences: persona, tone, core focus>

## Expertise

<bullet list of specific capabilities>

## Tool Usage

<only if tool guidance is non-default>

## Examples

<1-2 demonstrations for subjective or judgment tasks; omit for procedural agents>

## Output Format

<templates, JSON schema, or shape contract>

## Constraints

<what NOT to do>
```

The seven-element template (role, mission, capabilities, process, constraints, output format, examples) is the consensus across Anthropic, OpenAI, and Google guidance. See `references/structure.md` for filled examples per platform.

## Voice

- Second person, imperative. "You are…", "Use X when Y."
- No first person ("I will…" reduces adherence).
- No "you should" - use the bare imperative.
- No hedging or filler. Skip "IMPORTANT" / "YOU MUST" caps; Opus 4.5+ and Sonnet 4.6 over-trigger on aggressive language.
- One default per decision. Mention alternatives only if behaviour diverges.

See `references/voice.md` for imperative-vs-descriptive rewrites.

## Token budgets

- 400-700 words / 500-3,000 chars / ≤200 lines.
- Up to 1,200 words / ~10,000 chars hard cap for prompts with examples.
- Keep OpenCode direct startup near the measured floor: about 15K tokens with MCPs disabled.
- Keep `/ready` close to direct startup and do not eager-load `delegate-task`; delegated sessions around 17K-18K are acceptable today.
- Under-10K total context remains useful compliance evidence, not a current OpenCode startup target; reduce `delegate-task` and always-listed skill or agent metadata first.
- Terse instructions outperform verbose ones (~5x fewer tokens, ~8% better compliance).

## Identifier rules

- 3-50 characters. Lowercase a-z, 0-9, hyphens.
- 2-4 words. No underscores. No reserved words (`anthropic`, `claude`).
- Avoid generic terms (`helper`, `assistant`, `agent`, `bot`).
- Match the `name:` field, the directory name, and the file basename exactly.

## Description and triggers

- One sentence. Front-load the use case.
- For sub-agents on Claude Code, add 2-4 `<example>` blocks (Context / user / assistant / `<commentary>`) inside the description. See `references/triggers.md`.
- For portable agents that target Codex, OpenCode, or Pi as well, keep the description plain prose; extra `<example>` blocks degrade gracefully on those platforms but add noise.

Description craft mirrors `write-skill`'s doctrine for `SKILL.md` descriptions; the difference is voice. Agent descriptions read in the third person from the routing layer's perspective but are triggered by user intent, exactly like skills.

## Tool guidance

- List tools the agent owns and tools it must not touch (least privilege).
- Tool documentation deserves as much engineering as the prompt itself.
- Omit the section entirely if the agent uses the default tool set.

## Examples policy

Required when:

- Output style is subjective (voice, tone, structure).
- Judgement decides what to include or exclude.
- The format is complex enough that prose description loses fidelity.

Optional when:

- The task is procedural with a single correct shape.
- Output is short, structured, or fully constrained by a schema.

Keep examples compact. Use `<example_input>` / `<example_output>` tags.

## Update flow

1. Read the agent prompt and any companion command prompts.
2. Identify original intent before changing it.
3. Diagnose: voice, structure, redundancy, missing examples, contradictions.
4. Flag contradictions explicitly before editing (e.g. "be concise" alongside "be thorough"); pick a default in the rewrite.
5. Apply surgical edits. Preserve output format templates, few-shot examples, decision criteria, explicit constraints, tool-specific guidance, and numeric limits.
6. Record the change as a changelog.

## Output

When invoked to **create**, produce the complete agent prompt at the requested path.

When invoked to **update**, produce the edited prompt plus this changelog:

```markdown
| Removed     | Rationale           |
| ----------- | ------------------- |
| `<section>` | `<why ineffective>` |

| Preserved   | Rationale          |
| ----------- | ------------------ |
| `<element>` | `<why it matters>` |

| Added       | Rationale        |
| ----------- | ---------------- |
| `<element>` | `<gap it fills>` |
```

Append a word count and a flag for any contradictions surfaced before editing.

If invoked as a sub-agent for routing reasons, follow the response contract from `delegate-task`.

## Anti-patterns

- Pre/post checklists or self-review instructions.
- Persona descriptions beyond 2-3 sentences.
- Vague terms with no criteria ("appropriate", "when needed", "if relevant").
- Repeated constraints across sections.
- Contradictions left unresolved.
- "Always use tools" / "never use tools" without a hierarchy.
- Output format described in prose rather than shown.
- Generic LLM behaviours ("be proactive", "ask clarifying questions").
- AGENTS.md content (project rules, build commands) inside the agent prompt - that belongs in `AGENTS.md`; see `write-agents-md`.
- Frontmatter fields beyond `name` and `description` on portable agents; see `write-skill/references/portability.md` for the field matrix.

## References

- `references/structure.md` - filled examples of the seven-element template per platform (Claude Code, Codex, Pi/OpenCode).
- `references/voice.md` - imperative-vs-descriptive rewrites; do/don't pairs.
- `references/triggers.md` - sub-agent description craft and `<example>` block format.

Related skills: `write-skill` (for `SKILL.md` files; shares description-craft doctrine), `write-agents-md` (for project instruction files).
