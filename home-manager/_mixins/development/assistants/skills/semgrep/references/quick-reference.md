# Semgrep Quick Reference

> **Official Documentation:**
> - [Rule Syntax](https://semgrep.dev/docs/writing-rules/rule-syntax) - Complete reference
> - [Rule Schema](https://github.com/semgrep/semgrep-interfaces/blob/main/rule_schema_v1.yaml) - Full YAML/JSON schema

## Required Rule Fields

```yaml
rules:
  - id: rule-id              # Lowercase with hyphens
    languages: [python]      # Target language(s)
    severity: ERROR          # ERROR, WARNING, INFO
    message: "Description"   # Shown when rule matches
    pattern: func(...)       # Or patterns, pattern-either, mode: taint
```

## Supported Languages

**General purpose:** Python, JavaScript, TypeScript, Java, Go, Ruby, C, C++, C#, PHP, Rust, Kotlin, Swift, Scala, Lua, OCaml, R

**Config/Markup:** JSON, YAML, HTML, XML, Terraform (HCL), Dockerfile, Bash

## Pattern Operators

### Basic Matching

| Operator | Purpose | Example |
|----------|---------|---------|
| `pattern` | Single pattern | `pattern: eval(...)` |
| `patterns` | AND - all must match | See below |
| `pattern-either` | OR - any can match | See below |

```yaml
# AND - all must match
patterns:
  - pattern: $FUNC(...)
  - metavariable-regex:
      metavariable: $FUNC
      regex: ^(eval|exec)$

# OR - any can match
pattern-either:
  - pattern: eval(...)
  - pattern: exec(...)
```

### Metavariables

| Syntax | Description |
|--------|-------------|
| `$VAR` | Named metavariable (uppercase) |
| `$_` | Anonymous placeholder |
| `$...VAR` | Match zero or more arguments |
| `...` | Ellipsis - match anything |

```yaml
# Examples
pattern: $FUNC($ARG)           # Capture function and arg
pattern: func($_, $IMPORTANT)  # Ignore first, capture second
pattern: func($...ARGS)        # Capture all arguments
pattern: func(...)             # Match any arguments
```

### Deep Matching

```yaml
# Match nested expression anywhere
pattern: <... $EXPR ...>

# Example: find user_input anywhere in expression
pattern: dangerous(<... user_input ...>)
# Matches: dangerous(user_input)
# Matches: dangerous(process(user_input))
# Matches: dangerous(a, b, transform(user_input))
```

### Scope Operators

| Operator | Purpose |
|----------|---------|
| `pattern-inside` | Match only inside this scope |
| `pattern-not-inside` | Match only outside this scope |

```yaml
patterns:
  - pattern-inside: |
      def $FUNC(...):
        ...
  - pattern: return $SENSITIVE
  - pattern-not-inside: |
      if $CHECK:
        ...
```

### Negation

| Operator | Purpose |
|----------|---------|
| `pattern-not` | Exclude these patterns |
| `pattern-not-regex` | Exclude regex matches |

```yaml
patterns:
  - pattern: cursor.execute($QUERY)
  - pattern-not: cursor.execute("...", (...))  # Exclude parameterized
```

### Metavariable Filters

| Operator | Purpose |
|----------|---------|
| `metavariable-regex` | Filter by regex |
| `metavariable-pattern` | Filter by pattern |
| `metavariable-comparison` | Numeric comparison |
| `focus-metavariable` | Report on specific part |

```yaml
patterns:
  - pattern: $OBJ.$METHOD(...)
  - metavariable-regex:
      metavariable: $METHOD
      regex: ^(execute|query|run)$
  - metavariable-comparison:
      metavariable: $NUM
      comparison: $NUM > 100
  - focus-metavariable: $OBJ
```

## Taint Mode

### Basic Structure

```yaml
rules:
  - id: injection-rule
    mode: taint
    languages: [python]
    severity: ERROR
    message: Tainted data flows to sink
    pattern-sources:
      - pattern: request.args.get(...)
    pattern-sinks:
      - pattern: dangerous_function(...)
    pattern-sanitizers:
      - pattern: sanitize(...)
```

### Taint Components

| Component | Purpose |
|-----------|---------|
| `pattern-sources` | Where tainted data originates |
| `pattern-sinks` | Dangerous functions receiving taint |
| `pattern-sanitizers` | Functions that clean taint |
| `pattern-propagators` | Custom taint propagation rules |

### Source/Sink Options

```yaml
pattern-sources:
  - pattern: source(...)
    exact: true           # Only exact match (default: false)
    by-side-effect: true  # Taints variable by side effect

pattern-sinks:
  - patterns:
      - pattern: sink($QUERY, $PARAMS)
      - focus-metavariable: $QUERY  # Only $QUERY must be tainted
    # NOTE: Sinks default to exact: true

pattern-sanitizers:
  - pattern: sanitize(...)
    by-side-effect: true  # Sanitizes for subsequent use
```

### Propagators

```yaml
pattern-propagators:
  - pattern: $TO = transform($FROM)
    from: $FROM
    to: $TO
```

## Testing

### Test Annotations

```python
# ruleid: rule-id      # Must flag next line
vulnerable_code()

# ok: rule-id          # Must NOT flag next line
safe_code()

# todoruleid: rule-id  # Known limitation (should match)
# todook: rule-id      # Known false positive (shouldn't match)
```

**CRITICAL**: Annotation must be on line IMMEDIATELY BEFORE the code.

### Commands

```bash
semgrep --test --config rule.yaml test-file     # Run tests
semgrep --validate --config rule.yaml           # Validate YAML
semgrep --dump-ast -l python file.py            # Show AST
semgrep --dataflow-traces -f rule.yaml file     # Debug taint
semgrep -f rule.yaml file                       # Run single rule
```

## Common Patterns by Vulnerability

### SQL Injection

```yaml
mode: taint
pattern-sources:
  - pattern: request.args.get(...)
  - pattern: request.form[...]
pattern-sinks:
  - pattern: cursor.execute($Q, ...)
    focus-metavariable: $Q
  - pattern: db.execute($Q)
pattern-sanitizers:
  - pattern: int(...)
```

### Command Injection

```yaml
mode: taint
pattern-sources:
  - pattern: request.args.get(...)
pattern-sinks:
  - pattern: os.system(...)
  - pattern: subprocess.call($CMD, shell=True, ...)
    focus-metavariable: $CMD
pattern-sanitizers:
  - pattern: shlex.quote(...)
```

### XSS

```yaml
mode: taint
pattern-sources:
  - pattern: request.args.get(...)
pattern-sinks:
  - pattern: render_template_string(...)
  - pattern: Markup(...)
pattern-sanitizers:
  - pattern: escape(...)
  - pattern: bleach.clean(...)
```

### Path Traversal

```yaml
mode: taint
pattern-sources:
  - pattern: request.args.get(...)
pattern-sinks:
  - pattern: open($PATH, ...)
    focus-metavariable: $PATH
  - pattern: os.path.join(..., $PATH, ...)
pattern-sanitizers:
  - pattern: secure_filename(...)
```

### Hardcoded Secrets (Pattern Matching)

```yaml
pattern-either:
  - pattern: password = "..."
  - pattern: api_key = "..."
  - pattern: secret = "..."
  - patterns:
      - pattern: $VAR = "..."
      - metavariable-regex:
          metavariable: $VAR
          regex: (?i)(password|secret|api_key|token)
```

### Dangerous Functions (Pattern Matching)

```yaml
pattern-either:
  - pattern: eval(...)
  - pattern: exec(...)
  - pattern: compile(..., ..., "exec")
```

## Metadata Fields

```yaml
rules:
  - id: my-rule
    metadata:
      cwe: "CWE-89: SQL Injection"
      owasp: "A03:2021 - Injection"
      confidence: HIGH
      category: security
      references:
        - https://owasp.org/...
    fix: cursor.execute($QUERY, (params,))  # Auto-fix suggestion
```

## Path Filtering

```yaml
rules:
  - id: my-rule
    paths:
      include:
        - src/
        - lib/
      exclude:
        - src/generated/
        - "*_test.py"
```
