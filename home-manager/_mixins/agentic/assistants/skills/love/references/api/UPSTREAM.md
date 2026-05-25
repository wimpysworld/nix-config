# Upstream attribution

Vendored snapshot of the LÖVE per-module API skills from RedKenrok/skills.

- Source: https://github.com/RedKenrok/skills
- Commit: `949eb63540a8a8de706d6b2fb7d6bd7d006bd16d`
- Retrieved: 2026-05-24
- License: MIT (see `LICENSE-upstream.md`)
- Copyright: Ron Dekker <rondekker.nl>

## Contents

One directory per upstream module skill, matching upstream's
`skills/<module>/SKILL.md` layout so the upstream `../love-*/SKILL.md`
cross-links between modules resolve in-place.

- `love/SKILL.md` - top-level LÖVE skill index.
- `love-audio/SKILL.md`, `love-data/SKILL.md`, `love-event/SKILL.md`,
  `love-filesystem/SKILL.md`, `love-font/SKILL.md`, `love-graphics/SKILL.md`,
  `love-image/SKILL.md`, `love-joystick/SKILL.md`, `love-keyboard/SKILL.md`,
  `love-math/SKILL.md`, `love-mouse/SKILL.md`, `love-physics/SKILL.md`,
  `love-sound/SKILL.md`, `love-system/SKILL.md`, `love-thread/SKILL.md`,
  `love-timer/SKILL.md`, `love-touch/SKILL.md`, `love-video/SKILL.md`,
  `love-window/SKILL.md` - per-module API references.

These nested `SKILL.md` files are nested inside the `love` skill's
`references/` tree. The repo's skill composition only discovers
top-level `skills/<name>/SKILL.md`, so they are not registered as
separate skills; they exist solely as reference material for the
top-level `love` skill.

Files are verbatim copies of upstream `SKILL.md` bodies including their YAML
frontmatter. Cross-links inside the files use the upstream
`../love-*/SKILL.md` form and now resolve against the sibling module
directories in this layout.

Do not edit these files in place. Refresh by re-vendoring from upstream at a
newer commit and updating this file.
