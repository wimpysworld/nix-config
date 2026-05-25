## Project Orientation

Focus: `$ARGUMENTS` (if empty, orient on the whole repository).

**If AGENTS.md exists:** Read it, skip to Report.

**If missing:**

1. README.md for overview
2. CONTRIBUTING.md or ARCHITECTURE.md if present
3. Recent commits: `git log --oneline -10`
4. Tech stack from package manifests

**Markers:** ⚠️ WARNING (non-obvious behaviour), 📌 IMPORTANT (critical info).

### Report (50-100 lines)

| Section          | Content                                                        |
| ---------------- | -------------------------------------------------------------- |
| Summary          | What we're building, current state (2-3 sentences)             |
| Tech Stack       | Language, framework, key dependencies                          |
| Commands         | Build, test, run (3-5 most common)                             |
| Conventions      | Code style, structure, testing                                 |
| Constraints      | Version locks, platform requirements                           |
| Suggested Skills | Skills the next agent should load, with a one-line reason each |

End with: **Ready**: Orientation complete

### Example

<example>
**Summary**
CLI for validating OpenAPI schemas against live APIs. v0.3.2, pre-1.0.

**Tech Stack**
Go 1.22, Cobra CLI, go-openapi/spec, zerolog

**Commands**

- `go build ./cmd/validator`
- `go test ./...`
- `./validator check ./examples/petstore.yaml`

**Conventions**
Table-driven tests, errors via `fmt.Errorf`, commands in `/cmd`, packages in `/internal`.
📌 All exported errors wrap a sentinel from `internal/errs` so callers can `errors.Is` cleanly.

**Constraints**
Must support Go 1.21+ (CI matrix).
⚠️ `go-openapi/spec` is pinned - upgrading breaks `$ref` resolution in nested schemas.

**Suggested Skills**

- `nix` - the dev shell and release build are driven by the flake at `flake.nix`.
- `gh` - release workflow and issue triage run through GitHub Actions and `gh` CLI.

**Ready**: Orientation complete
</example>

### Constraints

- AGENTS.md takes precedence over all other files
- Read config files over source code
- Note gaps and ask rather than over-researching
- Link, do not duplicate; cite paths and one-line summaries rather than copying file contents.
- Redact secrets, credentials, tokens, passwords, private keys, and personal data.
