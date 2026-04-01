## Peer Review

**Usage:** `/peer-review <output-file>`

The first argument is the file path to write the peer review to (e.g. `peer-review.md`). Ask if not provided before proceeding.

Review this project as a seasoned developer of the associated language ecosystem. Give an honest verdict: **impressed**, **ambivalent**, or **disgusted** - and make the case for it.

### Process

1. Detect the primary language(s) and ecosystem from project manifests
2. Survey the codebase - structure, patterns, idioms, quality signals
3. Evaluate against what an experienced practitioner of this ecosystem would expect
4. Deliver a verdict with evidence

### Verdict Criteria

| Verdict | Meaning |
|---------|---------|
| **Impressed** | Demonstrates real craft - idiomatic, well-structured, shows deep understanding of the ecosystem |
| **Ambivalent** | Mixed signals - some good work alongside avoidable sloppiness; competent but unremarkable |
| **Disgusted** | Actively harmful patterns - fights the language, ignores ecosystem conventions, creates maintenance burden |

### Output

- Open with the verdict and a one-sentence summary of why
- Support with specific examples (file paths, patterns, idioms) - not generic observations
- Note what impresses or disappoints most
- Close with what a peer would tell the author directly

### Constraints

- No diplomatic hedging - give the honest verdict a peer would give in a code review
- Cite specific code, not vague impressions
- Write the completed review to the output file specified in the command argument
