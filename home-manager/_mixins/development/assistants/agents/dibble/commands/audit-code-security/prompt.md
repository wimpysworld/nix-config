## Code Security Audit

**Usage:** `/audit-code-security <output-file>`

The first argument is the file path to write the completed audit report to (e.g. `audit-2026-03-18.md`). Ask if not provided before proceeding.

Conduct a structured code security audit following a five-phase methodology. This command overrides Dibble's default directory sweep with a prioritised, threat-driven approach.

### Phase 1: Scope and Context

Before patrolling any code:

1. **Clarify scope** - Full codebase, specific module, or changed files (PR review); ask if not specified
2. **Identify technology stack** - Languages, frameworks, dependencies, infrastructure; flag if LLM libraries are present (`anthropic`, `openai`, `langchain`, `llamaindex`, `transformers`, `litellm`, `mistralai`, `google-generativeai`)
3. **Map entry points** - HTTP handlers, message consumers, file upload handlers, CLI parsers, environment variable readers, cron jobs processing external data
4. **Establish threat model** - Default: external attacker with no prior access; ask if a different model applies
5. **Review prior findings** - Check for existing audit reports, security notes, or TODO/FIXME security comments in source; treat each as an unconfirmed finding and confirm or dismiss during Phase 3

### Phase 2: Automated Scanning

**2a. Static Analysis (SAST)**

Use the Semgrep skill to run:

```
semgrep --config p/security-audit --config p/owasp-top-ten --config p/cwe-top-25 .
```

Triage results before proceeding. Confirm true positives as findings. Dismiss false positives with a documented rationale. Do not surface Semgrep false positives as patrol findings.

**2b. Secret Detection**

Run Gitleaks across the repository:

```
gitleaks detect --source . --report-format json
gitleaks git --source . --report-format json
```

Check `.env` files, configuration templates, CI/CD workflow files, and Dockerfiles. Flag any finding from git history as "confirmed - secret exposed in git history" even if removed from current code - history is permanent.

**2c. Dependency Scanning (SCA)**

Run OSV-Scanner against all lock files in the repository:

```
osv-scanner scan --recursive .
```

For each finding, record: package name, installed version, CVE/GHSA ID, and severity. Also flag manually:

- Version ranges instead of pinned exact versions (supply chain risk)
- Packages with no upstream activity in 24+ months
- npm packages with `postinstall` scripts (potential supply chain vector)

**2d. LLM Security (conditional)**

If LLM libraries were flagged in Phase 1, invoke the llm-security skill and audit against OWASP Top 10 for LLM Applications 2025. Priority categories:

| Category | ID | What to Check |
|----------|----|--------------|
| Prompt injection | LLM01 | Untrusted input reaching system prompts; indirect injection via retrieved content |
| Sensitive information disclosure | LLM02 | PII or credentials in prompts, context, or responses; training data leakage |
| Supply chain | LLM03 | Unverified model sources, unpinned model versions, third-party plugin trust |
| Improper output handling | LLM06 | LLM output rendered as HTML, executed as code, or passed to shell without sanitisation |
| Excessive agency | LLM07 | Agent granted permissions beyond task scope; irreversible actions without confirmation |
| Unbounded consumption | LLM10 | No token limits, no rate limiting, no cost controls on API calls |

### Phase 3: Manual Code Review

Manual review targets business logic, design flaws, and context-dependent vulnerabilities that automated tools miss.

**3a. Data Flow Tracing**

For each entry point from Phase 1, trace data to sensitive sinks:

| Sink Category | Check |
|--------------|-------|
| Database queries | Parameterised? ORM safe? Raw string concatenation? |
| OS commands | Shell disabled? Input escaped? Allowlist enforced? |
| File system | Path traversal prevention? Outside webroot? Filename sanitised? |
| HTML rendering | Context-appropriate encoding? Template auto-escape enabled? |
| External requests | URL validated? SSRF prevention? Allowlist for destinations? |
| Deserialisation | Trusted source only? Type restrictions enforced? |
| Auth/authz decisions | Check present? Bypassable? IDOR via user-controlled ID? |

**3b. Vulnerability Hunting by Priority**

Walk each category in order. Document findings before moving to the next.

| Priority | Category | CWE | Key Patterns |
|----------|----------|-----|-------------|
| 1 | Access control | CWE-862, CWE-863, CWE-639 | Missing authz checks, IDOR via user-controlled IDs, privilege escalation paths, role confusion |
| 2 | Authentication | CWE-306, CWE-287, CWE-384 | Unauthenticated critical functions, session fixation, token leakage |
| 3 | Injection | CWE-89, CWE-78, CWE-79, CWE-94 | SQL, OS command, XSS, code injection via unsanitised input |
| 4 | Cryptography | CWE-327, CWE-798, CWE-311, CWE-295 | Weak algorithms, hardcoded keys, cleartext storage, disabled TLS verification |
| 5 | Input validation | CWE-20, CWE-434 | Missing validation, unrestricted file upload, type confusion |
| 6 | Configuration | OWASP A02:2025 | Debug mode in production, default credentials, permissive CORS, missing security headers |
| 7 | Error handling | CWE-209, CWE-390 | Stack traces in responses, sensitive data in logs, inconsistent exception handling |
| 8 | Supply chain | OWASP A03:2025 | Unpinned deps, unverified downloads, abandoned packages, typosquatting signals |
| 9 | Resource limits | CWE-400, CWE-770 | Missing rate limits, unbounded allocations, absent timeouts, no request size caps |

**3c. Business Logic Review**

Automated tools cannot find these - requires understanding the application's purpose:

- Can workflows complete out of order or skip required steps?
- Can numeric values (price, quantity, discount) be manipulated client-side?
- Can one user access another user's data by substituting a resource ID?
- Are time-of-check/time-of-use (TOCTOU) races possible in critical operations?
- Can batch operations amplify impact beyond single-request limits?
- Are rate limits enforced server-side, not client-side only?

### Phase 4: Finding Triage

Each finding must include:

| Field | Requirement |
|-------|------------|
| CWE/OWASP | Required for every finding |
| Location | `file:line` |
| Severity | Critical / Warning / Observation |
| Confidence | Confirmed / Probable / Unverified |
| Exploitation path | Step-by-step; use Observation severity if no viable path exists |
| Impact | Data theft / RCE / privilege escalation / DoS / information leakage |
| Fix | Specific to the actual code - never generic advice |

Severity criteria:

- **Critical** - Remotely exploitable without authentication; direct high-impact outcome (RCE, auth bypass, mass data exposure, full privilege escalation)
- **Warning** - Exploitable under specific conditions or with authentication; significant but bounded impact
- **Observation** - Defence-in-depth gap, low exploitability, or theoretical without a clear exploitation path

### Phase 5: Report

Use Dibble's standard Patrol Report format (defined in Dibble's system prompt) with these additions:

**Methodology** - Phases completed, Semgrep rulesets run, scope covered, and explicit limitations (e.g., "git history not audited", "runtime behaviour not tested", "deployment configuration not reviewed").

**Repeat-Offender Patterns** - Systemic issues appearing across multiple files (e.g., "no parameterised queries in any repository layer", "CORS set to wildcard in all service configurations"). These indicate missing controls, not individual bugs, and require systemic fixes.

**Remediation Roadmap** - Prioritised fix list grouping related findings. Critical findings first, then ordered by effort-to-impact ratio.

Write the completed report to the output file specified in the command argument.

### Constraints

- Run Semgrep before any manual review
- Document every Semgrep true positive as a finding; never discard without rationale
- Triage all nine vulnerability categories from Phase 3b before closing the audit
- Flag items requiring git history, runtime, or deployment context review explicitly
- Never report a finding as Critical or Warning without a viable exploitation path; use Observation severity if no clear path exists
