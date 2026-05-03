## Standard Library Review

Hunt for code that reimplements what the standard library already provides. Custom utilities,
hand-rolled helpers, vendored snippets - if the stdlib covers it at the project's target version,
it has no business being here.

### Scope

Specify focus (or reviews entire codebase):

| Scope | Example |
|-------|---------|
| Recent changes | `git diff main`, specific PR |
| Directory | `src/utils/` |
| File | Single file deep-dive |
| Language | "Go only", "Python only" |

### Process

1. Detect languages and target versions from project manifests and toolchain files,
   preferring explicit runtime declarations over inference
   (`go.mod`, `pyproject.toml`, `Cargo.toml`, `.tool-versions`, `.python-version`,
   `package.json`, etc.)
2. For each language, establish stdlib capabilities at the project's target version
   using language-specific MCP or official docs first, then Context7, then
   `mcp__exa__web_search_exa` and `mcp__exa__web_fetch_exa`
3. Identify code reimplementing stdlib functionality:
   custom utilities, helper functions, vendored snippets, third-party packages
   with stdlib equivalents
4. Skip wrappers that enforce policy, preserve public API stability, or support
   older runtimes the project still targets
5. Report only replacements you can tie to the project's declared target version
6. Prioritise findings that are widely reused, costly to maintain, or riskier
   than the stdlib replacement
7. Flag each finding with:
   - What was reimplemented
   - The stdlib replacement and where to find it
   - Minimum version required, and whether it matches the project target

### Output Per Finding

- **Reimplementation:** what is being duplicated
- **Replace with:** stdlib package, function, or type
- **Since:** language version where this became available
- **Location:** file and line reference

### Example Invocations

<examples>
- "stdlib review of src/utils/"
- "Find reimplemented stdlib in recent changes"
- "stdlib review of the entire project"
- "stdlib review - Go only"
</examples>
