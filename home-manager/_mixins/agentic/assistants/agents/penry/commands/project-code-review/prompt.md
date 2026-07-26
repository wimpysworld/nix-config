## Project Code Review

Review code for maintainability defects that can be fixed by removing, simplifying, replacing, or clarifying code.

Runs a full-project review. No arguments.

### Report Location

Write the report to:

```
${TMPDIR:-/tmp}/agent-reviews/<project>/code-review.md
```

- `<project>` is the repository directory name, kebab-case.
- Create the directory if it does not exist.

The report is disposable. It lasts for one review only. Never commit it and never write it inside the repo.

Report the written path in your output so the user can find it.

### Process

1. Invoke `less-is-more` to reload the Communication Rules before writing anything. Codex uses `$less-is-more`; slash-command runtimes use `/less-is-more`. If the platform cannot expand a command, apply the Communication Rules directly.
2. Delegate to a wide fan-out of sub-agents, in parallel where possible. Split by directory, concern, or language so each sub-agent has a small review surface. Recurse into nested directories when useful. First-party code only; exclude git submodules. Each sub-agent runs this review over its own area; the parent aggregates findings.
3. Detect languages and target versions from project manifests and toolchain files, preferring explicit runtime declarations over inference (`go.mod`, `pyproject.toml`, `Cargo.toml`, `.tool-versions`, `.python-version`, `package.json`, etc.).
4. Hunt first for code that can disappear:
   dead code, unreachable blocks, unused exports/functions, commented-out code, obsolete feature flags, dead config, unused flexibility, one-implementation interfaces, factories with one product, wrappers that only delegate, and uncalled code paths.
5. Hunt next for code that can be replaced:
   hand-rolled standard library behaviour, third-party packages with standard library equivalents, custom platform wrappers where the language or framework already provides the feature, and helper files that export one thin thing.
6. Hunt last for code that can shrink:
   duplicated logic, needless abstraction, over-wide APIs, repeated conditionals, and verbose code that can become the same logic in fewer lines.
7. For standard-library and native replacements, verify the replacement against the project's target version. Use official docs or language-specific MCP tools first, then Context7, then Exa.
8. Skip wrappers that enforce policy, preserve public API stability, or support older runtimes the project still targets.
9. Ignore formatting preferences, naming taste, and stylistic nits unless they materially harm comprehension.
10. Rate each finding by impact (1-10): 4-5 local friction, 6-7 recurring maintenance cost, 8-10 structural drag.
11. Include dead code with clear evidence even when small. Skip other findings rated below 4.
12. Output per-improvement format from agent definition. For standard-library and native findings, add what was reimplemented, the replacement, the minimum version, and whether the project target permits it.
13. End the report with an estimated removal summary: lines, files, and dependencies that could be deleted.
14. Write the aggregated report to the derived path, then report that path.

### Restraint

- An empty or short report is a valid result. If the code holds up, say so and stop. Do not pad the report with borderline findings to look thorough.
- Report defects present in the code now. Do not raise speculative problems that depend on a future the code has not reached.
- Each finding must leave the code smaller or clearer. If a fix trades one shape for another of equal weight, drop it. Do not propose change for its own sake.
- Recommend one fix per finding. Do not list rival approaches or reopen a call you have already made.
