## Project Peer Review

Review this project as a seasoned developer of the associated language ecosystem. Give an honest verdict: **impressed**, **ambivalent**, or **disgusted** - and make the case for it.

Runs a full-project peer review. No arguments.

### Report Location

Write the review to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/<target>/peer-review.md
```

Load the `review-report-path` skill and derive `<project>` and `<target>` from it. This command takes no argument, so the target is the checkout it runs in.

### Process

1. Invoke `less` to reload the Communication Rules before writing anything. Codex uses `$less`; slash-command runtimes use `/less`. If the platform cannot expand a command, apply the Communication Rules directly
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by subdirectory, recursing into every nested subdirectory, not only top-level ones. First-party code only: exclude git submodules. Each sub-agent runs this same peer review over its own directory; the parent aggregates the findings
3. Detect the primary language(s) and ecosystem from project manifests
4. Survey the codebase - structure, patterns, idioms, quality signals
5. Evaluate against what an experienced practitioner of this ecosystem would expect
6. Deliver a verdict with evidence
7. Load the `review-report-path` skill, derive the report path, write the review there, then report that path

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
- **Impressed** with few or no complaints is a valid verdict. Do not inflate minor gripes into faults to justify a harsher grade.
- Judge the code as it stands. Do not flag speculative problems that depend on a future the code has not reached.
- Write the aggregated review to the derived path, then report that path
