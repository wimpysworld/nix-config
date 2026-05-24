# Prompt Writing Research

Companion to `SKILL-WRIITING.md`. Assesses Rosey's four prompt-writing commands - `create-instructions` / `update-instructions` (AGENTS.md authoring) and `create-assistant` / `update-assistant` (agent system-prompt authoring) - against current best practice, and proposes the same shim-plus-shared-skill reorg.

## 1. Sources consulted

| # | Source | URL | Accessed | Authority |
|---|---|---|---|---|
| A1 | `agents.md` open spec home page | https://agents.md/ | 2026-05-24 | Canonical spec page; stewarded by the Agentic AI Foundation under the Linux Foundation. |
| A2 | OpenAI Codex - "Custom instructions with AGENTS.md" | https://developers.openai.com/codex/guides/agents-md | 2026-05-24 | Codex vendor docs; defines override file, discovery walk, 32 KiB cap, fallback filenames. |
| A3 | OpenAI Codex - Customization concept page | https://developers.openai.com/codex/concepts/customization | 2026-05-24 | Codex doctrine: "keep it small", feedback-loop updates, nesting near specialised work. |
| A4 | `openai/codex` `codex-rs/core/prompt.md` | https://github.com/openai/codex/blob/main/codex-rs/core/prompt.md | 2026-05-24 | The actual Codex system prompt that explains AGENTS.md precedence (nearest wins, user prompts override). |
| A5 | Codex CLI README | https://github.com/openai/codex/blob/9a8730f3/codex-cli/README.md | 2026-05-24 | Documents merge order and `--no-project-doc` / `CODEX_DISABLE_PROJECT_DOC`. |
| A6 | Anthropic - "How Claude remembers your project" (CLAUDE.md) | https://code.claude.com/docs/en/memory | 2026-05-24 | Vendor doctrine: ≤200 lines per file, imperatives, `.claude/rules/` for path-scoped rules, treat as context not config. |
| A7 | Anthropic - "Best practices for Claude Code" | https://code.claude.com/docs/en/best-practices | 2026-05-24 | The include/exclude table for CLAUDE.md content; "ask: would removing this cause mistakes?". |
| A8 | Anthropic Help Center - CLAUDE.md context | https://support.claude.com/en/articles/14553240 | 2026-05-24 | Loading mechanics (user message after system prompt, prompt-caching), ≤200 lines target. |
| A9 | Anthropic - "Prompting best practices" (Claude API) | https://docs.anthropic.com/claude/docs/chain-prompts | 2026-05-24 | XML tags, role-setting, tool-use triggering, "dial back aggressive language" for Opus 4.5+. |
| A10 | Anthropic - "Building effective agents" | https://www.anthropic.com/engineering/building-effective-agents | 2026-05-24 | ACI principles, tool-doc rigour, "spent more time on tools than the prompt". |
| A11 | `claude-code` `agent-development` SKILL.md | https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/agent-development/SKILL.md | 2026-05-24 | Anthropic-shipped agent-authoring skill: frontmatter, ≥2-4 trigger examples, second-person body, character-length bands. |
| A12 | `claude-code` agent-creation system prompt | …/agent-development/references/agent-creation-system-prompt.md | 2026-05-24 | The production prompt Anthropic uses to generate agents; JSON contract, identifier rules, persona/methodology/edge-case scaffold. |
| A13 | OpenAI - "Prompting" guide (Responses API) | https://developers.openai.com/api/docs/guides/prompting | 2026-05-24 | "Tone/role in system, task/examples in user"; few-shot in YAML/bullets; versioning + eval discipline. |
| A14 | OpenAI - Agent definitions guide | https://developers.openai.com/api/docs/guides/agents/define-agents | 2026-05-24 | `instructions` vs `prompt` vs context; when to split agents. |
| A15 | GPT-5.1 prompting guide | https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-1_prompting_guide | 2026-05-24 | "Surgical revision" methodology; flag contradictions like "be concise" vs "be complete"; small explicit edits over redesign. |
| A16 | OpenAI - "Best practices for prompt engineering" | https://help.openai.com/en/articles/6654000 | 2026-05-24 | Show-and-tell output format; "say what to do" not just what to avoid; instructions first then context. |
| A17 | Google - System instructions intro (Gemini) | https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/prompts/system-instruction-introduction | 2026-05-24 | Persona / format / style / goals taxonomy; system instructions apply across turns. |
| A18 | Google - Prompting strategies overview | https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/prompts/prompt-design-strategies | 2026-05-24 | Canonical component list (Objective, Instructions, Constraints, Context, Reasoning, Response format, Recap); XML-tagged template. |
| A19 | Pi `prompt-templates.md` (v0.75.3 docs) | …/pi-coding-agent/docs/prompt-templates.md | 2026-05-24 | Confirms `$1`, `$@`, `$ARGUMENTS`, `${@:N}` are documented for prompt-template invocation. |
| A20 | Pi `skills.md` (v0.75.3 docs) | …/pi-coding-agent/docs/skills.md | 2026-05-24 | Pi has no agent-scoped command namespace; commands are flat prompt templates. Skills load via `/skill:name`. |

Notes: A1 is normative for AGENTS.md but deliberately thin. A2-A5 (Codex) and A6-A8 (Anthropic) supply the only two opinionated vendor doctrines for AGENTS.md / CLAUDE.md content; everything else is community gloss. A11/A12 are the most relevant authoritative source for agent-prompt authoring because Anthropic ships its own agent-creation prompt openly.

## 2. AGENTS.md best practice synthesis

### 2.1 The portable spec (A1)

- No required fields. Plain Markdown. Any headings.
- One file at repo root; nested files in subdirectories override (nearest wins). Direct chat prompts override AGENTS.md.
- Popular sections: Project overview, Dev/setup commands, Build & test commands, Code style, Testing instructions, PR/commit conventions, Security considerations.
- Compatible with Codex, Cursor, Jules, Factory, Amp, Aider (`.aider.conf.yml: read: AGENTS.md`), Gemini CLI (`.gemini/settings.json`), GitHub Copilot coding agent.
- Migration: rename and symlink the legacy name (`AGENT.md`, `.cursorrules`, etc.).

### 2.2 Vendor extensions and constraints

| Aspect | Codex (A2-A5) | Claude Code / CLAUDE.md (A6-A8) | Cursor / `.cursorrules` | Aider | Gemini CLI | Pi |
|---|---|---|---|---|---|---|
| Canonical filename | `AGENTS.md` (+ `AGENTS.override.md`) | `CLAUDE.md` (+ `CLAUDE.local.md`, `.claude/rules/*.md`) | `.cursorrules` / `.cursor/rules/*.mdc` | any (configured) | any (configured) | `AGENTS.md` (matches Codex; no Pi-specific name) |
| Discovery | Project-root walk down to CWD; global `~/.codex/AGENTS.md`; first non-empty per directory; concatenated root-first | Ancestor walk up at session start; descendants lazy-loaded on first read; home file `~/.claude/CLAUDE.md` | Project-only; no nesting | Single file configured in `.aider.conf.yml` | Single file configured in `.gemini/settings.json` | n/a (Pi reads neither natively in 0.75.3; relies on user including the file in context manually or via `AGENTS.md` open ecosystem tools that share Pi's repo) |
| Conflict rule | Closer dir overrides; user prompt overrides AGENTS.md | Last loaded wins; user prompt overrides | Project rule overrides global | Single source | Single source | n/a |
| Size guidance | "Keep it small"; 32 KiB cap (`project_doc_max_bytes`) before truncation | ≤200 lines per file; longer files degrade adherence | Short, focused (community norm) | n/a | n/a | n/a |
| Disabling | `--no-project-doc`, `CODEX_DISABLE_PROJECT_DOC=1` | `claudeMdExcludes` in monorepos | n/a | n/a | n/a | n/a |
| Fallback names | Configurable via `project_doc_fallback_filenames` | None | None | Explicit | Explicit | n/a |

### 2.3 What every vendor says (the universal core)

1. **Imperatives over descriptions.** "Use TypeScript strict mode for new files", not "the project uses TypeScript" (A6).
2. **Concrete and verifiable.** Each rule should pass the "would removing this cause the agent to make mistakes?" test (A7).
3. **Don't restate language defaults.** Cut anything the model already knows from reading the code (A7).
4. **Keep it living.** Update when the agent gets something wrong twice, not preemptively (A3, A6, A8).
5. **Nest near specialised work.** Module-specific rules in `frontend/AGENTS.md`, not the root file (A1, A2, A6).
6. **Don't conflict with yourself.** Contradictions cause arbitrary choice; review and prune (A6, A8, A15).
7. **Cost is real but cached.** Files load every session; bloat wastes both context and signal (A6, A8).
8. **Treat as context, not enforced config.** Phrasing and structure determine adherence (A6, A9).

### 2.4 Recommended portable sections (synthesis of A1, A2, A6, A7)

```markdown
# Project name

Short purpose sentence. (1 line)

## Setup
<commands required to get a working dev env>

## Build & test
<runnable, copy-pasteable commands>

## Code style
<project-specific rules only; skip language defaults>

## Testing
<how to scope, what to run before commit, coverage expectations>

## PR / commit conventions
<branch naming, title format, required checks>

## Architecture notes
<non-obvious layout, module boundaries>

## Security & secrets
<what not to commit, where secrets live>

## Gotchas
<recurring surprises an agent should know>
```

Target 50-200 lines for a root file; nested files much shorter. Skip empty sections.

### 2.5 Anti-patterns (synthesised)

- Restating standard language conventions ("write clean code").
- File-by-file codebase tours; long API documentation (link instead).
- Generic LLM instructions ("be helpful", "ask clarifying questions").
- Time-sensitive content (dates, version numbers that drift).
- Frontmatter on AGENTS.md. The spec is plain Markdown; vendor parsers don't read frontmatter (A1).
- Persona/role text - that belongs in agent system prompts, not project instructions (A6, A14).

## 3. Agent system prompt best practice synthesis

### 3.1 Structural template (consensus across A11, A17, A18, A12)

```text
1. Role / identity        - one sentence, second person ("You are…")
2. Mission / objective    - what success looks like
3. Capabilities           - what the agent owns; what it delegates
4. Process / methodology  - the steps, kept short
5. Constraints            - explicit dos and don'ts; refusal / escalation
6. Output format          - templates, JSON schema, or shape contract
7. Examples (when needed) - few-shot for subjective or judgment work
```

Gemini (A18) wraps each in XML tags (`<OBJECTIVE_AND_PERSONA>`, `<INSTRUCTIONS>`, `<CONSTRAINTS>`, `<OUTPUT_FORMAT>`, `<FEW_SHOT_EXAMPLES>`, `<RECAP>`). Anthropic (A9) recommends XML tagging where structure matters but does not mandate it. OpenAI (A13, A16) prefers headers + `"""` fenced context.

### 3.2 Token budgets and length

| Source | Target |
|---|---|
| A11 (Anthropic, agent dev skill) | system prompt 500-3,000 chars best; ≤10,000 chars hard cap; description 200-1,000 chars with 2-4 examples |
| A6/A7 (Anthropic, CLAUDE.md) | ≤200 lines for project memory |
| Rosey current | 400-600 words, up to 700 with examples |
| Community evidence (cited by Rosey) | Terse outperforms verbose ~5x fewer tokens, ~8% better compliance |

The numbers are mutually consistent: aim for 400-700 words / 500-3,000 chars / ≤200 lines. The cap matters less than killing duplication.

### 3.3 Voice and tone

- **Second person, imperative.** "You are …", "Use X when Y." (A11, A12, A17). Rosey already enforces this for agent bodies.
- **No first person.** "I will …" reduces adherence (A11).
- **No hedging or filler.** "IMPORTANT" / "YOU MUST" works on older Claude models but Opus 4.5+ over-triggers on aggressive language (A9). Default to plain imperatives.
- **No "you should".** Prefer the bare imperative. Rosey already encodes this.

### 3.4 Triggering and routing (for sub-agents)

- The `description` field is the routing surface; treat it like a skill description (A11).
- Include 2-4 `<example>` blocks with `Context`, `user`, `assistant`, `<commentary>` (A11, A12). This pattern is Claude-Code-specific but degrades gracefully on other platforms (extra text in the description).
- Identifier: 3-50 chars, lowercase, hyphens, 2-4 words, avoid generic terms ("helper", "assistant").

### 3.5 Tool guidance

- Define tools the agent owns and the ones it must not touch (A11).
- Tool docs deserve as much engineering as prompts (A10).
- Least-privilege: list tools explicitly when scoping matters.

### 3.6 Anti-patterns (synthesis A6, A11, A15, A16, plus Rosey's own list)

- Persona descriptions longer than 2-3 sentences.
- Pre/post checklists or self-review steps.
- Vague terms with no criteria ("appropriate", "when needed", "if relevant").
- Repeated constraints across sections.
- Contradictions ("be concise" alongside "be thorough") - flag explicitly and pick a default (A15).
- "Always use tools" / "never use tools" without a hierarchy.
- Output format described in prose rather than shown.

### 3.7 Token-efficiency patterns (Rosey's specialism, validated by sources)

- Imperatives, not explanations (A6, A13).
- Show formats with templates; don't describe them (A16).
- One default over many options; mention alternatives only if behaviour diverges (A11, A15).
- Move volatile material to references / on-demand resources (A6 `.claude/rules/`; the skill model generally).
- "Surgical revision" mindset for updates: small explicit edits, preserve structure (A15).

## 4. Gap analysis: `create-instructions` + `update-instructions`

Mapping each prompt's content against the AGENTS.md best-practice synthesis (§2). Verdicts: **keep**, **trim**, **add**, **rewrite**, **move to skill**.

| Element (source command) | Best-practice category | Verdict | Notes |
|---|---|---|---|
| "Create AGENTS.md using format from agents.md" (create) | A1 | Keep | Correct anchor URL. Pin it explicitly in the skill. |
| Analyse project: stack, conventions, build/test commands, manifests (create) | A1, A7 | Keep, move to skill | Same advice belongs in update too. |
| Section list: setup, build, test, style, testing, PR, security, architecture (create) | A1 §2.4 | Keep, move to skill | Matches consensus list almost exactly. Missing: "Gotchas / non-obvious behaviours" (A7 explicit). |
| "Skip sections with no project-specific content" (create) | A7 | Keep | Strong rule. |
| "Commands must be runnable (test them if possible)" (create) | A1 FAQ, A7 | Keep | Codex auto-runs them; A1 confirms. |
| "Target 50-150 lines" (create) | A2 (32 KiB), A6 (200 lines) | Trim and align | Bump upper bound to 200 lines to match CLAUDE.md guidance; keep 50 as a floor; clarify that nested files should be shorter. |
| "British English" (create) | repo `AGENTS.md` | Keep | Repo convention. |
| Two modes: targeted vs consolidation (update) | n/a | Keep | Useful framing; move to skill. |
| Consolidation file list: `AGENTS.md, CLAUDE.md, .claude/*, .cursorrules, .cursor/rules, .github/instructions/*.instructions.md` (update) | A1 migration FAQ | Add: `CLAUDE.local.md`, `.claude/rules/*.md` (A6), `AGENTS.override.md` (A2), `.aider.conf.yml`-referenced files (A1), `.gemini/settings.json` `context.fileName` target (A1). | List is incomplete relative to the current ecosystem. |
| Review criteria table (instructions/output/examples/decision criteria/constraints/tool guidance/persona) (update) | A11, A18 | Trim | This table is **system-prompt** criteria, not AGENTS.md criteria. Persona belongs to agent prompts (A6, A14); AGENTS.md should have no persona. Move table to `write-assistant`. |
| Assessment scale (✅⚠️🔧❌) (update) | n/a | Keep, move to skill | Generic review primitive; shared by both `write-agents-md` and `write-assistant`. |
| Output template (Rating / Issues / Changes made) (update) | A15 (surgical revision) | Keep, rewrite slightly | Add a `Conflicts` row to surface contradictions before edits (A6, A15). |
| "Output requirements: pure Markdown, no frontmatter" (update) | A1 | Keep | Correct - the open spec is plain Markdown. |
| "Logical sections (setup, build, test, style, constraints)" (update) | A1, §2.4 | Trim | Replace with the §2.4 canonical list to align create+update. |
| "Cite vendor guidance when flagging issues (Anthropic, OpenAI, Google)" (update) | n/a | Keep | Habit that prevents drift. |
| "Flag command prompts that duplicate base agent constraints" (update) | A6, A15 | Keep | Useful, but applies to agent prompts more than AGENTS.md. Consider moving to `write-assistant`. |
| Missing: imperatives over descriptions | A6, A13, A16 | **Add** | Universal vendor rule; absent from both commands. |
| Missing: nest near specialised work; nearest file wins; lazy-load semantics | A1, A2, A6 | **Add** | Materially affects what to put where in a monorepo. |
| Missing: 200-line / 32 KiB hard limits and why (cache + adherence) | A2, A6, A8 | **Add** | Currently 50-150 is asserted without justification. |
| Missing: "would removing this cause mistakes?" test | A7 | **Add** | The most-cited Anthropic heuristic; one sentence. |
| Missing: no frontmatter, no persona, no LLM-generic boilerplate | A1, A6 | **Add** | Common author mistake. |
| Missing: "user prompts override AGENTS.md" | A1, A4 | **Add** | Helps avoid over-specifying. |
| Missing: imperative tone for AGENTS.md content | A6 | **Add** | Currently implicit. |
| Duplication between create and update | n/a | **Move to skill** | Sections list, line target, British English, runnable-commands rule, output shape - all duplicated or near-duplicated. |

### Drift / contradictions

- `update-instructions` asks for a review table whose criteria (persona, output format, examples, tool guidance) match **agent system prompts** (A11, A18), not project instruction files (A1, A6). This conflates the two artefacts and pulls AGENTS.md towards a structure the spec discourages. Move that table to `write-assistant`.
- `create-instructions` does not state that AGENTS.md uses plain Markdown with no frontmatter; `update-instructions` does. Align.
- Line target differs implicitly (create: 50-150; update: "logical sections" no number). Pick one in the skill.

## 5. Gap analysis: `create-assistant` + `update-assistant`

| Element | Best-practice category | Verdict | Notes |
|---|---|---|---|
| "Gather: name, role/purpose, capabilities; example pair if judgment; tools if needed" (create) | A11, A12 | Keep, move to skill | Matches Anthropic's agent-creation prompt almost exactly (A12 "extract core intent"). |
| "Infer without asking: output format, constraints" (create) | A11, A15 | Keep | Anti-clarification bias is healthy. |
| "Target 400-600 words (up to 700 with examples)" (create) | A11 (500-3,000 chars best) | Keep | Word target maps roughly to 2,500-4,000 chars; close enough. |
| "Output: complete agent prompt only" (create) | A12 | Keep | |
| Rosey's own "Agent Structure" template (in Rosey prompt) | A11, A17, A18 | Keep | Already aligned: frontmatter, Role & Approach, Expertise, Tool Usage, Examples, Output Format, Constraints. |
| "Apply ineffective patterns list from base instructions" (update) | A15 | Keep | Surgical revision. |
| "Preserve output format templates and constraints" (update) | A15 | Keep | Explicit preservation list. |
| "Gap check: missing examples, decision criteria, constraints" (update) | A11, A15, A16 | Keep | |
| Changelog (Removed / Preserved / Added with rationale) (update + Rosey prompt) | A15 | Keep | Strong, already in Rosey's prompt. |
| "Review for context efficiency" (update) | A6, A9 | Keep | |
| Missing: explicit second-person, imperative-voice requirement | A11, A12, A17 | **Add** | Rosey's prompt encodes it implicitly via "never use 'You should'"; make it a positive rule. |
| Missing: 2-4 trigger `<example>` blocks for sub-agents in Claude Code | A11, A12 | **Add (with portability caveat)** | Mirror the SKILL `write-skill` portability handling: portable agents skip; Claude-Code-targeted agents include. |
| Missing: identifier rules (3-50 chars, lowercase, hyphens, no underscores, avoid generic terms) | A11, A12 | **Add** | |
| Missing: "dial back aggressive language" warning | A9 | **Add** | Specifically relevant to Opus 4.5+ and Sonnet 4.6 which Rosey targets. |
| Missing: "flag contradictions explicitly" methodology | A15 | **Add** | GPT-5.1 prompting guide's headline practice; one paragraph. |
| Missing: tool documentation rigour ("tools deserve as much prompt engineering as prompts") | A10 | **Add** | Relevant when the agent has tools beyond Read/Write/Edit. |
| Missing: how to write the YAML frontmatter `description` for routing | A11 | **Add** | Same craft as skill descriptions; reuse the doctrine from `write-skill`. |
| Missing: relationship between agent persona length and adherence | A6, A11 | **Add (in skill)** | Rosey already says "persona beyond 2-3 sentences" is ineffective; the source backs this up - cite. |
| Duplication: writing principles, ineffective-patterns list, output template - all live in Rosey's own prompt | n/a | **Resolve** | The current setup leaves doctrine in the agent prompt itself, with the commands referring to it implicitly ("Apply ineffective patterns list from base instructions"). Move doctrine to `write-assistant` skill; trim Rosey's prompt to a pointer. |

### Drift / contradictions

- `update-assistant` is almost contentless and relies on Rosey's prompt for all the doctrine. This is the inverse of `update-instructions`, which has too much. Aligning both pairs on the skill model normalises this.
- Rosey's own prompt currently contains the **full** agent-authoring doctrine (Writing Principles, When Examples Are Essential, Ineffective Patterns, High-Value Patterns, Output Format, Changelog Format). With a `write-assistant` skill, most of this moves out of the agent prompt and into the skill, leaving Rosey's prompt as a tight persona that references the skill. This is the same move made for `write-skill` and is consistent with A6: keep the always-loaded surface lean.

## 6. Proposed shared-skill scope

### 6.1 `write-agents-md` (new skill)

**Path:** `home-manager/_mixins/agentic/assistants/skills/write-agents-md/SKILL.md`

**Frontmatter (draft):**

```yaml
---
name: write-agents-md
description: Use when creating, updating, consolidating, or reviewing an AGENTS.md (or CLAUDE.md / .cursorrules / similar) project instruction file. Covers the open agents.md spec, Codex precedence rules, Claude Code memory loading, and migration from legacy formats. Use even if the user only says "instructions", "rules", or "project memory".
---
```

**Body scope (≤500 lines, target ≤200):**

1. One-line restatement.
2. Decision rules: root vs nested; new file vs edit; consolidation vs targeted update.
3. Mechanics: filename and discovery per platform (Codex, Claude Code, Cursor, Aider, Gemini, Pi). Open-spec rules: plain Markdown, no frontmatter, no required fields.
4. Recommended portable section list (the §2.4 template).
5. Content rules: imperatives, "would removing this cause mistakes?", no language defaults, no persona, no LLM-generic boilerplate, runnable commands, no time-sensitive content, no frontmatter.
6. Sizing: 50-200 lines for root; shorter for nested; cite 32 KiB Codex cap and 200-line Claude target.
7. Consolidation flow: discovery list (`AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/*.md`, `.cursorrules`, `.cursor/rules/*.mdc`, `.github/instructions/*.instructions.md`, Aider/Gemini-configured files), extract project-specific, dedupe, flag conflicts, preserve runnable commands, propose deletions but require confirmation.
8. Review criteria + assessment scale + output template (Rating, Issues, Conflicts, Changes made).
9. Update flow: surgical edits, no rewriting, changelog table.
10. Anti-patterns (the §2.5 list).
11. Output: edited or new file plus changelog.

**References:**

- `references/platforms.md` - per-platform discovery, override, and disabling matrix (Codex, Claude Code, Cursor, Aider, Gemini CLI, Pi). Source: A2, A5, A6, A1 FAQ. ≤100 lines.
- `references/sections.md` - the canonical section template with one example each.
- `references/migration.md` - rename + symlink recipes for legacy filenames (A1 FAQ).

**Shims:**

```text
.../rosey/commands/create-agents-md/prompt.md
.../rosey/commands/update-agents-md/prompt.md
```

Each is 4-6 lines, mirroring the existing `create-skill` shim: pass `$1` as the path, instruct Rosey to load `write-agents-md` and run the create or update flow.

### 6.2 `write-assistant` (new skill)

**Path:** `home-manager/_mixins/agentic/assistants/skills/write-assistant/SKILL.md`

**Frontmatter (draft):**

```yaml
---
name: write-assistant
description: Use when creating, updating, refactoring, or reviewing an AI assistant or sub-agent system prompt - persona, role, capabilities, tools, output format, examples, and constraints. Covers Claude Code agents, OpenAI Codex / Responses-API agents, Pi assistants, and OpenCode agents. Use even if the user says "agent prompt", "assistant", "subagent", or "persona".
---
```

**Body scope:**

1. One-line restatement.
2. Decision rules: new agent vs edit vs split (mirror A14's split criteria - different tools, guardrails, model, or output style).
3. Required structure (the §3.1 template): Role, Mission, Capabilities, Process, Constraints, Output Format, Examples-when-needed.
4. Voice rules: second person, imperatives, no "you should", no first person, no aggressive caps (A9), one default per decision.
5. Token budgets: 400-700 words / 500-3,000 chars / ≤200 lines; cite Rosey's existing evidence and A11.
6. Frontmatter: portable `description`; sub-agent triggers with 2-4 `<example>` blocks where the target platform supports them (cross-link `write-skill`'s description-craft guidance to avoid duplication).
7. Identifier rules (A11): 3-50 chars, lowercase, hyphens, no underscores, avoid generic terms.
8. Tool guidance: list owned tools; least privilege; cite A10.
9. Examples policy: required for subjective/style/judgment agents; optional for procedural agents.
10. Update flow: surgical revision (A15) - flag contradictions before editing, small explicit edits, preserve structure unless duplication forces consolidation.
11. Output: edited prompt + changelog table (Removed | Rationale, Preserved | Rationale, Added | Rationale, plus Word/char count).
12. Anti-patterns: pre/post checklists, persona >2-3 sentences, vague terms, repeated constraints, prose output formats, "be proactive" generics.

**References:**

- `references/structure.md` - the §3.1 template with one filled example per platform (Claude Code, Codex, Pi/OpenCode).
- `references/voice.md` - imperative-vs-descriptive rewrites; do/don't pairs.
- `references/triggers.md` - sub-agent description craft and `<example>` block format (link to `write-skill/references/portability.md` where relevant).

**Shims (names unchanged):**

```text
.../rosey/commands/create-assistant/prompt.md
.../rosey/commands/update-assistant/prompt.md
```

### 6.3 What stays in shims

Each shim is 4-8 lines and does only:

1. Capture the argument: `Target: $1. If blank, ask for the <path|name>.`
2. Name the flow: "Run the **create** (or **update**) flow."
3. Point at the skill: "Load the `write-agents-md` (or `write-assistant`) skill and apply it end-to-end. Do not duplicate that guidance here."

Pattern is identical to `create-skill/prompt.md` (verified in §0 read).

### 6.4 What stays in Rosey's own prompt

After the reorg, Rosey's prompt drops the bulk of the Output Format, Writing Principles, Ineffective Patterns, and Changelog templates - they live in `write-assistant` and `write-agents-md`. Rosey keeps the persona (2-3 sentences), the universal constraints (token target, no checklists, British English, no emojis), and pointers to the three writing skills (`write-skill`, `write-agents-md`, `write-assistant`). Estimated saving: 60-70% of Rosey's current body.

This is **out of scope for the deliverable** but listed for completeness; see §9.

## 7. Recommendations

Ordered by leverage. Sizes: S (≤1h), M (half-day), L (full day or more).

1. **(L) Author `write-agents-md/SKILL.md` and its three references.** Move all AGENTS.md doctrine here. Rationale: removes 80%+ duplication between `create-instructions` and `update-instructions`, adds the missing universal rules (imperatives, "removal test", precedence, no-frontmatter), and aligns vendor coverage across Codex / Claude / Cursor / Aider / Gemini / Pi. Cites A1-A8, A19, A20.  
    *Rejected alternative:* keep doctrine in commands. Drift between create and update is already observable (the review-criteria table appears only in update, and conflates agent-prompt criteria with project-instruction criteria). Same failure mode as the pre-reorg `create-skill` / `update-skill`.

2. **(L) Author `write-assistant/SKILL.md` and its three references.** Move agent-authoring doctrine out of Rosey's own prompt and out of both `*-assistant` commands. Rationale: Rosey's prompt currently carries the doctrine inline; that bloats the always-loaded surface (A6) and forces `update-assistant` to depend implicitly on Rosey ("Apply ineffective patterns list from base instructions"). Cites A9-A18.  
    *Rejected alternative:* leave doctrine in Rosey's prompt. The skill model exists exactly for description-triggered, on-demand loading; using a top-level agent prompt as a library is the anti-pattern A6 calls out.

3. **(S) Replace four command bodies with shims.** `create-agents-md`, `update-agents-md` (renamed from `*-instructions`), `create-assistant`, `update-assistant`. Each 4-8 lines. Match the existing `create-skill` shim exactly. Rationale: enforces single-source doctrine; future updates touch one skill, not four prompts.

4. **(S) Update header metadata.** New `description.txt` and `header.*.yaml` for the renamed `*-agents-md` commands. Preserve the existing `agent: rosey` / `model: opus` / `argument-hint:` patterns from the skill-command pair.  
    *Rejected alternative:* keep `create-instructions` / `update-instructions` names for backwards compatibility. The user's brief specifies the rename. Add a one-line deprecation note in commit message if older shells still use the old names.

5. **(M) Trim Rosey's own prompt.** After the two skills exist, cut Rosey's Output Format, Changelog, Writing Principles, and Ineffective Patterns sections down to skill pointers. Keep persona, universal constraints, British English, and the existing reference to `write-skill`. Out of scope for this brief; flagged so it is not forgotten.

6. **(S) Audit existing repo AGENTS.md against the new skill.** Identify where the project's own root `AGENTS.md` conflicts with the new doctrine (e.g. line target, missing sections). Spot-check; do not rewrite as part of this work.

7. **(S) Add cross-references between the three writing skills.** `write-skill`, `write-agents-md`, and `write-assistant` share doctrine on: description craft, third- vs second-person voice, anti-patterns, and changelog formats. Link rather than duplicate.

Rejected alternatives at the architecture level:

- **One mega-skill `writing-things`.** Rejected: the three artefacts (skill, project instructions, agent prompt) have materially different voice rules (third person vs imperative descriptive vs second-person imperative) and different size budgets. One skill would either bloat or paper over the distinctions.
- **No skill, just consolidated commands.** Rejected for the same reason as the skill-writing reorg: progressive disclosure beats prompt-template inheritance, especially for Pi which loads skills on demand but loads prompt templates eagerly only when invoked.

## 8. Open questions / blockers

1. **Pi positional-arg semantics in prompt-templates.** Resolved: `prompt-templates.md` (A19) explicitly documents `$1`, `$2`, `$@`, `$ARGUMENTS`, `${@:N}`, `${@:N:L}`. Shims can rely on `$1` on Pi exactly as on Claude Code (`$ARGUMENTS`) and OpenCode. The blocker noted in `SKILL-WRIITING.md` open-questions referred to **skill** invocation (`/skill:name`), which is a different surface; for commands the path is clear.
2. **`/agent:rosey:<command>` style invocations.** Pi has no agent-scoped command namespace in 0.75.3: commands are flat prompt templates (A19, A20). The OpenCode header (`agent: rosey`) binds commands to Rosey at the OpenCode layer, not Pi's. So shims work the same way they do for `create-skill` - confirmed by direct read of the existing `create-skill/prompt.md`.
3. **Where the new shims live.** Reuse the existing `commands/<name>/{prompt.md, description.txt, header.*.yaml}` layout. Confirm with the user that the rename (`*-instructions` → `*-agents-md`) carries through on OpenCode and Claude headers without breaking inbound references.
4. **`write-assistant` vs `write-skill` overlap.** Both cover description craft, anti-patterns, and changelog formats. Decide whether to extract a third shared reference (e.g. `skills/_shared/description-craft.md`) or to cross-link with `references/`. Recommendation: cross-link; a third shared file is over-abstraction at this scale.
5. **British English in skill bodies.** Repo `AGENTS.md` mandates British English. The existing `write-skill` skill already conforms; new skills must match.
6. **Plain Markdown vs frontmatter on AGENTS.md.** The spec (A1) is unambiguous: no frontmatter. But some vendor parsers (Cursor `.mdc`) do read YAML. The `write-agents-md` skill should default to no frontmatter and call out the Cursor-only exception.
7. **Whether to support the Codex `AGENTS.override.md` workflow explicitly.** Not in the current `update-instructions` command. Worth adding a one-paragraph section in `write-agents-md` because Codex is one of the three primary targets.
8. **Trigger overlap between `write-agents-md` and the existing repo convention of using `AGENTS.md`.** Make the skill's description trigger on `instructions`, `rules`, `project memory`, `CLAUDE.md`, `.cursorrules`, and `AGENTS.md` so it loads regardless of vocabulary.

## 9. Out of scope

- **Rosey's own `prompt.md`.** Touch only as part of recommendation 5, in a follow-up task. The current research does not justify rewriting Rosey unilaterally - the prompt is already aligned with A6/A11 voice doctrine. The slim-down only becomes worthwhile **after** the two new skills exist.
- **Other Rosey commands (`offboard`, `create-skill`, `update-skill`).** `create-skill`/`update-skill` were settled by the prior reorg; `offboard` is unrelated.
- **The repo's own root `AGENTS.md` content.** Recommendation 6 flags an audit but does not commit to edits.
- **Publishing skills externally** (e.g. as a Codex `agents/openai.yaml` companion). Same conclusion as `SKILL-WRIITING.md`: only relevant if the repo wants to share skills beyond its own machines.
- **Theme/keybinding/extension/TUI Pi surfaces.** Not implicated by this work.
- **The `header.*.yaml` model and effort settings.** Adopt existing values from the skill-command pair unless the user explicitly wants to revisit them.
