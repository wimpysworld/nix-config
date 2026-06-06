## Cleanse Comments

Comment-quality pass over $1. Cleanse noise and strengthen weak comments without changing behaviour. Comments only - any edit that touches logic is out of scope: flag it, never make it.

Default $1 to the working tree's changed files; if there are none, the whole tree. $2 narrows scope (a subtree, a symbol, or "all").

### Workflow

1. Resolve $1 to a file set; apply $2 as a filter
2. Read each file and classify every comment: cleanse, preserve, or improve
3. Edit comments only; leave code untouched
4. Run the project's formatter and tests to prove behaviour is unchanged
5. Report per-file counts plus any behavioural concern you refused to touch

### Cleanse - remove or rewrite

1. Self-evident narration that restates the next line (`Sort by name` above a sort, `Iterate through configs`, `Add to list`)
2. Dev-process metadata: task, phase, and ticket numbers, and changelog history baked into comments. Keep the durable technical rationale; drop the project-history narration
3. Filler: "for now", "we document the behavior", past-tense narration of what the author did
4. Hardcoded line-number references (`parser.go:619`). Replace with a semantic anchor - name the function, symbol, or purpose so the comment survives code movement
5. Past-tense regression-guard or process prose. Rewrite to present-tense design language describing what the code is and why

### Preserve - never delete

- The why: technical rationale, design decisions, invariants, concurrency and unsafe contracts, security notes
- Compiler and tooling directives and structured markers: `//nolint`, `//go:*`, build tags, substantive `TODO`/`FIXME`, IDE and doc pragmas. These are not prose
- Doc comments on exported or public symbols

### Improve - add or expand

- Add doc comments to exported or public symbols that lack them
- Expand a comment that states what but omits a non-obvious why

### Per-File Output

```markdown
**Comment Pass:**
| File | Removed | Rewritten | Added |
|------|---------|-----------|-------|
| `path/to/file` | 3 | 1 | 1 |

**Verification:**
| Check | Result |
|-------|--------|
| Formatter | ✅ Pass |
| Tests | ✅ 47 passed, 0 failed |

**Flagged (not touched):** [behavioural concerns spotted, with file and reason - omit if none]
```

### Constraints

- Touch comments only; if a fix needs a code change, flag it and move on
- Preserve existing comment style and language conventions
- Behaviour must be identical before and after; the test run proves it
