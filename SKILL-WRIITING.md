# Skill Writing Research

## Authoritative references

| # | Source | URL | Accessed | Key claim |
|---|---|---|---|---|
| R1 | Agent Skills open specification | https://agentskills.io/specification ; https://github.com/agentskills/agentskills/blob/main/docs/specification.mdx | 2026-05-24 | Frontmatter: required `name` (≤64 chars, lowercase alphanumeric+hyphens, no leading/trailing or consecutive hyphens, must match parent dir) and `description` (≤1024 chars, what+when, keyword-rich). Optional: `license`, `compatibility` (≤500 chars), `metadata`, `allowed-tools` (experimental). Three-tier progressive disclosure: metadata (~100 tok), SKILL.md body (<5000 tok), bundled resources on demand. Body unrestricted Markdown. |
| R2 | Anthropic "Skill authoring best practices" | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices | 2026-05-24 | Concise is paramount; assume Claude is smart. Reserved-word ban: `name` cannot contain "anthropic" or "claude". No XML tags in `name`/`description`. Prefer **gerund** naming (`processing-pdfs`). Write description in **third person**. Body ≤500 lines. References **one level deep** from SKILL.md. Reference files >100 lines need TOC. Avoid time-sensitive info; use consistent terminology. Avoid Windows paths. "Avoid offering too many options - provide a default." Build ≥3 evaluations *before* writing. Test across Haiku/Sonnet/Opus. Match "degrees of freedom" (instructions/pseudocode/scripts) to task fragility. |
| R3 | Anthropic Claude Code skills doc | https://code.claude.com/docs/en/skills.md | 2026-05-24 | Claude Code extends the open standard. Optional fields: `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context`, `agent`, `hooks`, `paths`, `shell`. `description`+`when_to_use` truncated at 1,536 chars in listing. Custom commands and skills have merged: `.claude/commands/x.md` and `.claude/skills/x/SKILL.md` both yield `/x`. Skill content stays in context after invocation; write as standing instructions. |
| R4 | Anthropic `claude-code` `skill-development` skill | https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/skill-development/SKILL.md | 2026-05-24 | Three-tier model formalised: metadata (~100 words), body (<5k words, target 1,500-2,000), resources (unlimited). Description must be **third person** ("This skill should be used when…"). Include explicit trigger phrases. Validation checklist covers structure, body length, references existence, examples, scripts. |
| R5 | OpenAI Codex Agent Skills | https://developers.openai.com/codex/skills ; https://developers.openai.com/codex/concepts/customization | 2026-05-24 | Codex implements the standard. Loads from `.agents/skills/` (repo) and `$HOME/.agents/skills` (user). Invoked via `$skill-name` or implicitly. Skill listing capped at ~2% of context window; front-load key use case in description. `agents/openai.yaml` adds UI metadata + `allow_implicit_invocation`. Plugins are the distribution unit; skills are the authoring format. |
| R6 | OpenAI `skill-creator` skill | https://github.com/openai/skills/blob/main/skills/.system/skill-creator/SKILL.md | 2026-05-24 | Single skill handles both create and update workflows. "Include all 'when to use' information in the description, not in the body - the body is only loaded after triggering." Avoid duplicating info between SKILL.md and references. Move material to references when content >10k tokens or contains many variants. |
| R7 | Pi `skills.md` | https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md | 2026-05-24 | Pi implements the standard leniently. Locations: `~/.pi/agent/skills/`, `~/.agents/skills/`, `.pi/skills/`, `.agents/skills/`. Invoked `/skill:name`. Direct `.md` files (no SKILL.md) allowed in `~/.pi/agent/skills/` and `.pi/skills/`. Validation issues warn but still load; missing description blocks load. Models don't always auto-load; prompt or `/skill:name` to force. |
| R8 | RedKenrok `writing-skill-md` | https://raw.githubusercontent.com/RedKenrok/skills/refs/heads/main/skills/writing-skill-md/SKILL.md | 2026-05-24 | Concise restatement of the open spec. Notes `allowed-tools` is experimental and "should only be used in controlled environments". Reference files should be "focused and small"; references one level deep. |
| R9 | `mgechev/skills-best-practices` | https://github.com/mgechev/skills-best-practices | 2026-05-24 (community/opinion) | Do **not** create `README.md`, `CHANGELOG.md`, `INSTALLATION_GUIDE.md` inside skills - skills are for agents, not humans. No library code inside `scripts/`. Just-in-Time loading: instruct the agent explicitly when to read each file. Third-person imperative. Flat one-level subdirs only. |
| R10 | Anthropic Help Center custom skills | https://support.anthropic.com/en/articles/12512198-creating-custom-skills | 2026-05-24 | Description cap stated as 200 characters (Anthropic UI advice; conflicts with spec 1024). Skills can build on each other implicitly; cannot explicitly reference each other. Test with example prompts to verify invocation. |

Confidence note: R1-R7 are authoritative current docs. R8 mirrors R1. R9 is opinion but widely cited. R10 contains a stricter older limit that contradicts the current open spec.

## Current Rosey artefacts

- `rosey/prompt.md`: agent persona for *prompt + skill* editing. Writing principles target token efficiency, imperatives, examples policy. Tool list: Read/Edit/Write. Constraints encode prompt-length targets and forbid checklists, generic LLM behaviours, emoji. Skills are mentioned only in the role description; no skill-specific doctrine in the agent prompt itself.
- `commands/create-skill/prompt.md`: covers SKILL.md frontmatter (`name`, `description`), directory layout (`scripts/`, `references/`, `assets/`), three-tier progressive disclosure, reference + task skill types, body writing tips, "slightly pushy" description guidance with good/bad examples, constraint that body ≤500 lines and reference TOC over 300 lines. British English.
- `commands/update-skill/prompt.md`: near-duplicate of `create-skill`. Diagnostic checklist for description/instructions/structure/resources. Same writing principles, same description guidance, same 500/300 limits. Preserves name.
- Headers select `opus` on Claude, `claude-opus-4-7` and `gpt-5.5` high-effort on pi/Codex; OpenCode binds commands to the `rosey` agent.
- Existing skills under `assistants/skills/` already use spec-compliant frontmatter with `name` + multi-sentence trigger-rich `description`, mostly with `references/`, demonstrating the target form.

## Gap analysis

High-confidence gaps (backed by ≥1 authoritative source):

1. **Frontmatter coverage is incomplete.** Neither command mentions optional spec fields `license`, `compatibility`, `metadata`, `allowed-tools`, nor Claude-Code extensions `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `paths`, `model`, `effort`, `context`, `agent`. `create-skill` does name two of these (`user-invocable: false`, `disable-model-invocation: true`) but without spec citation or noting they are Claude-Code-specific (R1, R3).
2. **Hard limits not stated.** `description` ≤1024 chars; `name` ≤64; combined listing text truncated at 1,536 chars in Claude Code and ~2% context budget in Codex (R1, R3, R5).
3. **Name rules incomplete.** Missing: must match parent directory exactly; no leading/trailing or consecutive hyphens; reserved words `anthropic`/`claude` banned (R1, R2). `create-skill` says "1-64 characters" but omits the rest.
4. **Description should be third-person.** Rosey's "slightly pushy" guidance is good but never specifies third person. Anthropic explicitly warns against first/second person in description (R2, R4, R6).
5. **Reference TOC threshold.** Rosey says 300 lines; Anthropic best-practices says 100 lines (R2). Either revise to 100 or qualify Rosey's number.
6. **One-level reference depth.** Anthropic and mgechev both insist references must link **directly** from SKILL.md; nested references cause partial reads (R2, R9). Not in Rosey.
7. **All "when to use" belongs in description, not body.** Body is only loaded after triggering, so a "When to use" body section cannot drive selection (R6). Some existing repo skills already violate this (e.g. `nix/SKILL.md` has minimal description and pushes triggers into the body).
8. **Avoid time-sensitive language; use consistent terminology; avoid Windows paths; prefer a default over many options.** None of these appear in Rosey (R2).
9. **Skill-types model is Claude-Code-specific.** "Reference vs Task" framing maps to Claude Code's `user-invocable`/`disable-model-invocation` knobs (R3). Cross-platform skills should not lean on these without noting portability.
10. **No portability framing.** Commands target "Claude Code, OpenCode, and Codex" but say nothing about the open spec at `agentskills.io`, nor about Pi which the rest of this repo uses (R1, R7). Pi-specific discovery paths and `/skill:name` invocation are absent.
11. **Evaluation-driven development missing.** Anthropic's headline practice ("build ≥3 evaluations first") is not in Rosey (R2).
12. **Anti-patterns missing.** Don't create `README.md`/`CHANGELOG.md` inside skills; don't bundle library code in `scripts/`; don't duplicate info between body and references (R6, R9).
13. **Duplication.** `create-skill` and `update-skill` repeat ~70% of doctrine: description guidance, writing principles, structural limits, constraints. Drift risk is real and already visible (`create-skill` mentions `disable-model-invocation`/`user-invocable`, `update-skill` does not).
14. **Gerund naming convention.** Anthropic recommends gerund form (`writing-skill`, `processing-pdfs`) for naming consistency (R2). Not in Rosey.

Lower-confidence/opinion gaps:

- Body word target 1,500-2,000 words (R4) vs Rosey's line-only limit. Useful but soft.
- Three-model testing matrix (R2). Useful for shared repos.
- `agents/openai.yaml` companion file for Codex distribution (R5, R6). Niche unless skills are published.

## Recommendations

| # | Recommendation | Rationale | Citation | Confidence |
|---|---|---|---|---|
| 1 | Consolidate skill-authoring doctrine into a single **skill** (`writing-skills/SKILL.md`) loaded by Rosey, and reduce commands to thin invocation shims (`/create-skill`, `/update-skill`) that delegate. | Matches the prevailing pattern: Anthropic ships `skill-development` as one skill; OpenAI ships `skill-creator` as one skill; RedKenrok ships `writing-skill-md`. Avoids the 70% doctrine duplication between Rosey's two commands. | R4, R6, R8 | High |
| 2 | State the open spec authoritatively in the skill: `name` ≤64 chars, lowercase a-z/0-9/hyphens, no leading/trailing or consecutive hyphens, must match parent dir, no XML tags, no reserved words `anthropic`/`claude`; `description` ≤1024 chars. | These are validated by Pi and required by the spec; current commands silently omit them. | R1, R2, R7 | High |
| 3 | Require descriptions written in **third person**, front-loaded with the key use case, including explicit trigger phrases. Keep the "slightly pushy" guidance; replace `disable-model-invocation`/`user-invocable` mentions with a portability note (open spec vs Claude-Code extension). | Codex and Anthropic both rank description as the primary discovery surface; third person avoids viewpoint conflicts when injected into system prompts. | R2, R4, R5, R6 | High |
| 4 | Replace the 300-line reference TOC threshold with **100 lines**. | Anthropic best-practices explicitly states 100 lines because Claude previews partial reads. | R2 | High |
| 5 | Add: references one level deep; use forward-slash paths; avoid time-sensitive content (or wrap in an "Old patterns" section); use consistent terminology; provide a single default over multiple options. | Anthropic anti-pattern list. | R2 | High |
| 6 | Add: "Put all when-to-use information in the description, not the body" with a note that body sections titled 'When to use' do not drive selection. | OpenAI/Codex skill-creator stresses this; current Rosey examples (`nix/SKILL.md`) violate it. | R6 | High |
| 7 | Add a brief anti-pattern list: no `README.md`/`CHANGELOG.md`/`INSTALLATION_GUIDE.md` inside skills; no library code in `scripts/`; no information duplicated across SKILL.md and references. | Keeps skills agent-shaped, not human-shaped. | R6, R9 | Medium-high |
| 8 | Document the optional frontmatter fields with a short portability matrix: open spec (`license`, `compatibility`, `metadata`, `allowed-tools`) vs Claude-Code-only (`when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `model`, `effort`, `context`, `agent`, `paths`, `hooks`, `shell`) vs Codex companion (`agents/openai.yaml`). | The repo targets Claude, OpenCode, Codex, and Pi; authors need to know which fields are portable. | R1, R3, R5, R7 | High |
| 9 | Recommend **gerund-form** skill names (`writing-skills`, `processing-pdfs`) as default. | Anthropic naming convention. | R2 | Medium |
| 10 | Adopt evaluation-driven authoring: require ≥3 concrete trigger scenarios captured in the skill (in a `references/evaluations.md`) before declaring a skill done. | Anthropic identifies this as the single highest-leverage practice. | R2 | Medium |
| 11 | Note Pi specifics: discovery locations and `/skill:name` invocation; that Pi loads lenient and may not auto-invoke without prompting. | This repo is Pi-first; current commands don't acknowledge it. | R7 | High |
| 12 | Keep Rosey's existing strengths intact: imperative voice, "explain *why*", British English, ≤500 lines body, slightly-pushy descriptions, examples policy. | Already aligned with R2 and R4. | R2, R4 | High |

## Single vs split commands

**Recommend collapsing.** A single `writing-skills` skill (or a single command) is the dominant pattern in the authoritative ecosystem: Anthropic's `skill-development`, OpenAI's `skill-creator`, and RedKenrok's `writing-skill-md` all handle create-and-update from one artefact. The two Rosey commands already share ~70% of their bodies; drift between them is observable (e.g. `disable-model-invocation`/`user-invocable` appear only in `create-skill`). Collapsing has two viable shapes:

- **Option A (preferred):** one `writing-skills` skill containing all doctrine, plus one slash command `/skill` (or `/skills`) that takes a verb argument (`create|update|review <path>`) and loads the skill.
- **Option B:** keep two slash commands but reduce each to a 5-10 line preamble that calls Rosey and references the shared skill body.

Option A aligns with how skills are meant to work (description-triggered, body-on-demand) and removes the temptation to inline doctrine into command bodies.

## Implementation outline (high level only)

1. Author a new skill at `home-manager/_mixins/agentic/assistants/skills/writing-skills/SKILL.md` containing the doctrine listed in Recommendations 2-12.
2. Move long-form material (frontmatter field matrix, anti-patterns, evaluation template, examples) into `writing-skills/references/` files, each ≤100 lines or with a TOC.
3. Replace `commands/create-skill/prompt.md` and `commands/update-skill/prompt.md` with thin invokers (Option A: a single `/skill` command with an argument; Option B: two slim shims). Each command's job is to gather arguments and instruct the agent to load and apply the skill.
4. Update Rosey's `prompt.md` only to mention the skill exists; do not duplicate skill doctrine inside the agent prompt.
5. Audit existing skills under `assistants/skills/` against the new doctrine and file follow-ups for skills that put triggers in the body instead of the description (notably `nix`).
6. Add the `writing-skills` skill location to whatever discovery surface this repo exposes (already covered by the existing `skills/` directory pattern).

## Open questions

- Does Pi's `/skill:name` syntax compose with positional arguments the way Claude Code's `$ARGUMENTS` does? Pi docs are silent on argument passing into skills (R7). Implementation choice between Option A and B depends on this.
- Should the consolidated artefact be a **skill** (description-triggered, recommended by Anthropic) or a **command** (deterministic, always-invoked)? Skills win on portability and progressive disclosure but Rosey is already an agent and the user explicitly asked about *commands*. Confirm intent.
- Does the repo want to publish portable skills (open spec only) or accept Claude-Code-specific frontmatter? The portability matrix in Recommendation 8 should reflect the chosen target.
- The Anthropic Help Center (R10) quotes a 200-character description limit that contradicts the open spec's 1024. Treat 200 as legacy/UI advice; default to 1024 unless evidence of regression appears.
- Whether to add an `agents/openai.yaml` template for Codex distribution (R5, R6) - only matters if the repo will publish skills to Codex users.
