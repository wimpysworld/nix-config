---
name: write-skill
description: Use when creating, updating, or reviewing an Agent Skill - authoring or revising a `SKILL.md`, its frontmatter, layout, references, and progressive disclosure. Use when the user mentions writing, editing, splitting, renaming, or auditing a skill, even if they do not say "skill" explicitly. Covers cross-platform portability across Claude Code, Codex, OpenCode, and Pi.
---

# Write Skill

Author and maintain Agent Skills (`SKILL.md`) that load via description-triggered progressive disclosure. One artefact, two flows: create from scratch or update in place.

## Decide first

- **Create** vs **update** vs **split**. Split when a single skill mixes unrelated triggers, the body exceeds ~500 lines, or two distinct workflows compete for the description.
- **Skill** vs **command**. Skills are description-triggered and reusable; commands are deterministic and user-invoked. If the workflow needs an argument and a fixed name, build a command that loads the skill.
- **Add a reference** vs **enlarge the body**. Add a `references/<topic>.md` when material is needed only some of the time, exceeds ~100 lines, or contains variants that differ per task.

## Frontmatter (portable, required)

```yaml
---
name: <skill-name>
description: <third-person trigger sentence(s); what + when>
---
```

Rules:

- `name` matches the parent directory exactly. Lowercase a-z, 0-9, hyphens. ≤64 chars. No leading, trailing, or consecutive hyphens. No reserved words (`anthropic`, `claude`). Prefer gerund form (`writing-skills`, `processing-pdfs`).
- `description` ≤1024 chars. Third person. Front-load the use case. Include explicit trigger phrases and synonyms so the model selects the skill without being asked by name.
- Add platform-specific fields (`user-invocable`, `when_to_use`, `argument-hint`, `disable-model-invocation`, `allowed-tools`, …) **only if required** for behaviour on that platform. See `references/portability.md`.

## Body

Lean, imperative, action-oriented. Smaller is better. Cap at 500 lines; most skills stay well under that, often under 200. The body loads only after the description triggers, so put all when-to-use phrasing in the description, not in a "When to use" heading.

Structure:

1. One-line restatement of purpose.
2. Decision rules (when to do what).
3. Required mechanics (frontmatter, layout, output shape).
4. Anti-patterns.
5. Links to `references/` for material that is large, variant-heavy, or rarely needed.

## Layout

```
<skill-name>/
├── SKILL.md          required
├── references/       loaded on demand from SKILL.md links
├── scripts/          executable helpers (no library code)
└── assets/           templates, static files
```

- Reference files link **one level deep** from `SKILL.md`. No nested reference chains.
- Reference files >100 lines need a table of contents at the top.
- Use forward-slash paths.
- Do not bundle `README.md`, `CHANGELOG.md`, or installation guides inside a skill - skills are for agents, not humans.

## Description craft

Triggers drive selection. Be slightly pushy.

<example_good>
Use when the user mentions dashboards, data visualisation, or wants to display metrics, even if they do not ask for a "dashboard" explicitly.
</example_good>

<example_bad>
How to build a simple dashboard.
</example_bad>

## Token efficiency and cache stability

Skill text joins the cached prompt prefix once loaded. Static, short, stable bodies pay off across turns; volatile content erodes the cache.

- Keep static instructions stable; do not reshuffle headings or rewrite cosmetically.
- Move volatile, dated, or task-specific content into `references/` so the body stays cacheable.
- Prefer the smallest skill that does the job. Cut anything that does not change agent behaviour.
- Avoid persona, filler, hedging, duplicate style rules, and time-sensitive phrasing.
- No timestamps, session IDs, or rolling metrics in the body.
- Consistent terminology throughout; one term per concept.

## Update flow

1. Read `SKILL.md` and every file under `references/`, `scripts/`, `assets/`.
2. Identify original intent before changing it.
3. Diagnose: description triggers, instruction quality, structure, bundled resources, drift.
4. Preserve the `name` field and the directory name exactly. Never rename a live skill in place.
5. Edit narrowly. Move bulk to references rather than rewriting the body.
6. Record the change in the response as a short changelog (what changed, why).

## Versioning policy

Skills are not semver. Treat changes as:

- **Compatible**: description-trigger tweaks, body clarity, reference additions, anti-pattern updates. Edit in place.
- **Breaking**: renaming, removing triggers users rely on, changing required arguments. Create a new skill with a new name and leave the old one until callers migrate.

## Anti-patterns

- Triggers hidden in the body instead of the description.
- First- or second-person description ("You should …", "I will …").
- XML tags inside `name` or `description`.
- Reference TOC missing on files >100 lines.
- Library code in `scripts/`.
- Information duplicated between `SKILL.md` and a reference.
- Many options without a clear default - pick one default and mention alternatives only if behaviour diverges.
- Claude-Code-only frontmatter on skills intended to be portable.

## Output

When invoked to **create**, produce the new `SKILL.md` (and any references) in fenced blocks ready to save, at the correct path.

When invoked to **update**, produce the edited `SKILL.md` (and changed references) in fenced blocks plus a brief changelog: `Changed`, `Rationale`. Preserve unchanged sections verbatim.

If invoked as a sub-agent for routing reasons, follow the response contract from `delegate-task`: start non-artefact work with `Answer:`; return raw artefacts only when the artefact is the deliverable.

## References

- `references/portability.md` - frontmatter field matrix across Claude Code, Codex, OpenCode, Pi.
- `references/evaluations.md` - capture ≥3 concrete trigger scenarios before declaring a skill done.
