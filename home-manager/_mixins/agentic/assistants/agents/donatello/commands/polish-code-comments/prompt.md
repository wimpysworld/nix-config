## Polish Code Comments

Comment-quality pass over $1. Polish ensures comments are accurate and good enough to orient humans and agents new to the codebase. Improve weak comments where you can; remove only when a comment merely restates the code. This is an improver, not a cleanser. Comments only - any edit that touches logic is out of scope: flag it, never make it.

Default $1 to the working tree's changed files; if there are none, the whole tree. $2 narrows scope (a subtree, a symbol, or "all").

### Workflow

1. Resolve $1 to a file set; apply $2 as a filter
2. If the set spans multiple directories, dispatch one sub-agent per subdirectory, recursing into every nested subdirectory, not just top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same comment-polish pass over its own directory; the parent aggregates the per-file counts
3. Read each file and classify every comment: correct, improve, preserve, or remove
4. Edit comments only; leave code untouched
5. Run the project's formatter and tests to prove behaviour is unchanged
6. Report per-file counts plus any behavioural concern you refused to touch

### Correct - fix inaccuracy first

A comment that no longer matches the code is worse than none. This is the priority.

- Rewrite drifted, misleading, or outdated comments to describe current behaviour
- Replace hardcoded line-number references (`parser.go:619`) with a semantic anchor - name the function, symbol, or purpose so the comment survives code movement
- Rewrite past-tense regression-guard or process prose into present-tense design language describing what the code is and why
- Replace em dashes (—) and en dashes (–) in comment prose with a full stop between independent clauses, a comma otherwise. Leave dashes inside code, string literals, URLs, and structured markers untouched

### Improve - strengthen and orient

- Expand a comment that states what but omits a non-obvious why
- Add doc comments to exported or public symbols that lack them
- Add module, file, or function-level orientation where a newcomer (human or agent) would struggle to grasp purpose or non-obvious context

### Preserve - never delete

- The why: technical rationale, design decisions, invariants, concurrency and unsafe contracts, security notes
- Compiler and tooling directives and structured markers: `//nolint`, `//go:*`, build tags, substantive `TODO`/`FIXME`, IDE and doc pragmas. These are not prose
- Doc comments on exported or public symbols

### Remove - the narrow exception

Delete only when the comment adds nothing a reader cannot see in the code:

- Self-evident narration that restates the next line (`Sort by name` above a sort, `Iterate through configs`, `Add to list`)
- Dev-process metadata: task, phase, and ticket numbers, and changelog history baked into comments. Keep the durable technical rationale; drop the project-history narration
- Filler: "for now", "we document the behavior", past-tense narration of what the author did

### Per-File Output

```markdown
**Comment Pass:**
| File | Corrected | Improved | Removed |
|------|-----------|----------|---------|
| `path/to/file` | 2 | 2 | 1 |

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
