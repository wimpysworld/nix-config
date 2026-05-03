---
name: semgrep
description: "Run Semgrep static analysis scans and create custom detection rules. Use when asked to scan code with Semgrep, find security vulnerabilities, write custom YAML rules, or detect specific bug patterns. IMPORTANT: Also use this skill when users ask to 'scan for bugs', 'check code quality', 'find vulnerabilities', 'static analysis', 'lint for security', 'audit this code', or want to enforce coding standards — even if they don't mention Semgrep by name. Semgrep is the right tool for pattern-based code scanning across 30+ languages."
---

# Semgrep Static Analysis

Fast, pattern-based static analysis for security scanning and custom rule creation.

## MCP Tools Available

If Semgrep MCP tools are available in your environment, prefer them for scanning:

- **`semgrep_scan`** — Scan code files for security vulnerabilities using built-in rulesets. Pass absolute file paths and an optional config (e.g., `p/security-audit`, `auto`).
- **`semgrep_scan_with_custom_rule`** — Scan code with a custom YAML rule you've written. Pass code content inline along with the rule.
- **`semgrep_findings`** — Fetch existing findings from the Semgrep AppSec Platform for a repository.
- **`semgrep_rule_schema`** — Get the full schema for writing Semgrep rules.
- **`get_supported_languages`** — List all languages Semgrep supports.

When MCP tools aren't available, fall back to the CLI commands below.

## When to Use Semgrep

**Ideal scenarios:**
- Quick security scans (minutes, not hours)
- Pattern-based bug and vulnerability detection
- Enforcing coding standards and best practices
- Finding known vulnerability patterns (OWASP, CWE)
- Creating custom detection rules for your codebase
- Data flow analysis with taint mode

## Installation (CLI)

```bash
# pip (recommended)
python3 -m pip install semgrep

# Homebrew
brew install semgrep

# Docker
docker run --rm -v "${PWD}:/src" semgrep/semgrep semgrep --config auto /src
```

---

# Part 1: Running Scans

## Quick Scan

```bash
semgrep --config auto .                    # Auto-detect rules
```

## Using Rulesets

```bash
semgrep --config p/<RULESET> .             # Single ruleset
semgrep --config p/security-audit --config p/trailofbits .  # Multiple
```

| Ruleset | Description |
|---------|-------------|
| `p/default` | General security and code quality |
| `p/security-audit` | Comprehensive security rules |
| `p/owasp-top-ten` | OWASP Top 10 vulnerabilities |
| `p/cwe-top-25` | CWE Top 25 vulnerabilities |
| `p/trailofbits` | Trail of Bits security rules |
| `p/python` | Python-specific |
| `p/javascript` | JavaScript-specific |
| `p/golang` | Go-specific |

## Output Formats

```bash
semgrep --config p/security-audit --sarif -o results.sarif .   # SARIF
semgrep --config p/security-audit --json -o results.json .     # JSON
```

## Scan Specific Paths

```bash
semgrep --config p/python app.py           # Single file
semgrep --config p/javascript src/         # Directory
semgrep --config auto --include='**/test/**' .  # Include tests
```

## Configuration

### .semgrepignore

```
tests/fixtures/
**/testdata/
generated/
vendor/
node_modules/
```

### Suppress False Positives

```python
password = get_from_vault()  # nosemgrep: hardcoded-password
dangerous_but_safe()  # nosemgrep
```

---

# Part 2: Creating Custom Rules

## When to Create Custom Rules

- Detecting project-specific vulnerability patterns
- Enforcing internal coding standards
- Building security checks for custom frameworks
- Creating taint-mode rules for data flow analysis

## Approach Selection

| Approach | Use When |
|----------|----------|
| **Taint mode** | Data flows from untrusted source to dangerous sink (injection vulnerabilities) |
| **Pattern matching** | Syntactic patterns without data flow requirements (deprecated APIs, hardcoded values) |

**Prioritize taint mode** for injection vulnerabilities. Pattern matching alone can't distinguish between `eval(user_input)` (vulnerable) and `eval("safe_literal")` (safe).

## Quick Start: Pattern Matching

```yaml
rules:
  - id: hardcoded-password
    languages: [python]
    message: "Hardcoded password detected: $PASSWORD"
    severity: ERROR
    pattern: password = "$PASSWORD"
```

## Quick Start: Taint Mode

```yaml
rules:
  - id: command-injection
    languages: [python]
    message: User input flows to command execution
    severity: ERROR
    mode: taint
    pattern-sources:
      - pattern: request.args.get(...)
      - pattern: request.form[...]
    pattern-sinks:
      - pattern: os.system(...)
      - pattern: subprocess.call($CMD, shell=True, ...)
    pattern-sanitizers:
      - pattern: shlex.quote(...)
```

## Pattern Syntax Quick Reference

| Syntax | Description | Example |
|--------|-------------|---------|
| `...` | Match anything | `func(...)` |
| `$VAR` | Capture metavariable | `$FUNC($INPUT)` |
| `<... ...>` | Deep expression match | `<... user_input ...>` |

| Operator | Description |
|----------|-------------|
| `pattern` | Match exact pattern |
| `patterns` | All must match (AND) |
| `pattern-either` | Any matches (OR) |
| `pattern-not` | Exclude matches |
| `pattern-inside` | Match only inside context |
| `pattern-not-inside` | Match only outside context |
| `metavariable-regex` | Regex on captured value |

## Testing Rules

**Test-first is mandatory.** Create test files with annotations:

```python
# test_rule.py
def test_vulnerable():
    user_input = request.args.get("id")
    # ruleid: my-rule-id
    cursor.execute("SELECT * FROM users WHERE id = " + user_input)

def test_safe():
    user_input = request.args.get("id")
    # ok: my-rule-id
    cursor.execute("SELECT * FROM users WHERE id = ?", (user_input,))
```

Run tests:
```bash
semgrep --test --config rule.yaml test-file
```

## Command Reference

| Task | Command |
|------|---------|
| Run tests | `semgrep --test --config rule.yaml test-file` |
| Validate YAML | `semgrep --validate --config rule.yaml` |
| Dump AST | `semgrep --dump-ast -l <lang> <file>` |
| Debug taint flow | `semgrep --dataflow-traces -f rule.yaml file` |

## Rule Creation Workflow

1. **Analyse the problem** - Understand the bug pattern, determine taint vs pattern approach
2. **Create test cases first** - Write `ruleid:` and `ok:` annotations before the rule
3. **Analyse AST** - Run `semgrep --dump-ast` to understand code structure
4. **Write the rule** - Start simple, iterate
5. **Test until 100% pass** - No "missed lines" or "incorrect lines"
6. **Optimise patterns** - Remove redundancies only after tests pass

**Output structure:**
```
<rule-id>/
├── <rule-id>.yaml     # Semgrep rule
└── <rule-id>.<ext>    # Test file
```

## Detailed References

**Official Semgrep Documentation:**
- [Rule Syntax](https://semgrep.dev/docs/writing-rules/rule-syntax) - Complete YAML structure, operators, and options
- [Rule Schema](https://github.com/semgrep/semgrep-interfaces/blob/main/rule_schema_v1.yaml) - Full JSON schema specification

## Anti-Patterns to Avoid

**Too broad:**
```yaml
# BAD: Matches any function call
pattern: $FUNC(...)

# GOOD: Specific dangerous function
pattern: eval(...)
```

**Missing safe cases:**
```python
# BAD: Only tests vulnerable case
# ruleid: my-rule
dangerous(user_input)

# GOOD: Include safe cases
# ruleid: my-rule
dangerous(user_input)

# ok: my-rule
dangerous(sanitize(user_input))
```

## Rationalizations to Reject

| Shortcut | Why It's Wrong |
|----------|----------------|
| "Semgrep found nothing, code is clean" | Semgrep is pattern-based; can't track complex cross-function data flow |
| "The pattern looks complete" | Untested rules have hidden false positives/negatives |
| "It matches the vulnerable case" | Matching vulnerabilities is half the job; verify safe cases don't match |
| "Taint mode is overkill" | For injection vulnerabilities, taint mode gives better precision |
| "One test case is enough" | Include edge cases: different coding styles, sanitised inputs, safe alternatives |

---

# CI/CD Integration

## GitHub Actions

```yaml
name: Semgrep

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 1 * *'

jobs:
  semgrep:
    runs-on: ubuntu-latest
    container:
      image: returntocorp/semgrep

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Semgrep
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            semgrep ci --baseline-commit ${{ github.event.pull_request.base.sha }}
          else
            semgrep ci
          fi
        env:
          SEMGREP_RULES: >-
            p/security-audit
            p/owasp-top-ten
            p/trailofbits
```

---

# Resources

- Rule Syntax: https://semgrep.dev/docs/writing-rules/rule-syntax
- Pattern Syntax: https://semgrep.dev/docs/writing-rules/pattern-syntax
- Registry: https://semgrep.dev/explore
- Playground: https://semgrep.dev/playground
- Docs: https://semgrep.dev/docs/
