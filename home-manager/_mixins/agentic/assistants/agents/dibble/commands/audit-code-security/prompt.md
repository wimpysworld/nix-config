## Code Security Audit

Run a full-project code security audit. No arguments.

### Process

1. Delegate to a wide fan-out of sub-agents, in parallel where possible.
   Split by directory, concern, language, or attack surface so each sub-agent
   has a small audit surface. Recurse into nested directories when useful.
   First-party code only; exclude git submodules. Each sub-agent runs this audit
   over its own area; the parent aggregates findings.
2. Do not ask for a report path. If the audit scope is unclear, ask before you
   start.
3. This command may read source files, run the Bash checks below, and write only
   `CODE-SEC-AUDIT.md` in the project root. Do not edit source files or stage
   changes.
4. Conduct a threat-driven audit with the default model of an external
   unauthenticated attacker, unless the user states another one.

### 1. Scope and flow map

- Identify stack, deployment surface, trust boundaries, auth model, secrets stores, data classes, and prior security notes.
- Map sources: HTTP, webhooks, CLI args, queues, jobs, uploads, files, env/config, third-party callbacks, LLM prompts/RAG documents/tool results when present.
- Map sinks: database queries, OS commands, file paths, templates/HTML, redirects, outbound URLs, deserialisation, auth/authz decisions, logs, crypto, secrets, model/tool APIs when present.
- Trace source to sink. A finding needs a controllable source, reachable sink, missing control, and impact.

### 2. Automated checks

Run SAST first, then secrets and dependency checks. Run what is available. If a tool is missing or out of scope, record that limitation.

```bash
semgrep --config p/security-audit --config p/owasp-top-ten --config p/cwe-top-25 .
gitleaks detect --source . --report-format json
gitleaks git --source . --report-format json
osv-scanner scan --recursive .
```

Triage every result. Report confirmed true positives. Dismiss false positives with a short reason. Treat secrets found in git history as exposed. For dependency findings, record package, version, advisory ID, severity, and fix version.

### 3. Manual checklist

| Area                    | Checks                                                                                                                  |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Auth and access control | Missing authn/authz, IDOR, tenant isolation, role confusion, session flaws, JWT signature and expiry checks, CSRF.      |
| Injection               | SQL/NoSQL, OS command, code/eval, template, LDAP, XML/XXE, unsafe deserialisation, prototype pollution.                 |
| Web output              | XSS, open redirect, CORS, CSP, security headers, cookie flags, context-aware encoding.                                  |
| Files and parsers       | Path traversal, unsafe uploads, archive slip, temp files, MIME/type checks, parser features.                            |
| Network                 | SSRF, webhook trust, outbound allowlists, TLS verification, timeouts, cleartext transport.                              |
| Secrets and crypto      | Hardcoded secrets, weak random/hash/cipher, key storage, key rotation, cleartext storage, sensitive logs, stack traces. |
| Supply chain and CI     | Unpinned deps, actions, images, postinstall scripts, abandoned packages, typosquatting, unsafe PR workflows.            |
| Infrastructure          | Terraform/cloud public access, IAM least privilege, Kubernetes privileged pods/RBAC, Docker root/socket/secrets.        |
| Resource limits         | Rate limits, request size, pagination, regex DoS, memory/CPU bounds, queue back-pressure.                               |
| Native code             | Buffer overflow, use-after-free, integer overflow, unsafe functions, FFI boundary checks.                               |
| Race and logic          | TOCTOU, replay, double spend, client-side price/role trust, workflow order bypass, batch amplification.                 |

### 4. LLM app checks, conditional

Run this section only when the target uses LLMs, RAG, agents, tools, embeddings, model APIs, or libraries such as `openai`, `anthropic`, `langchain`, `llamaindex`, `transformers`, `litellm`, `mistralai`, or `google-generativeai`. Otherwise state `No LLM surface found` and skip it.

| OWASP LLM 2025                         | Checks                                                                                                    |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| LLM01 Prompt Injection                 | Direct and indirect injection from users, retrieved content, files, websites, emails, or tool results.    |
| LLM02 Sensitive Information Disclosure | PII, credentials, secrets, proprietary data in prompts, context, logs, responses, or training data.       |
| LLM03 Supply Chain                     | Model provenance, pinned model versions, safe model loading, trusted plugins/tools, dependency integrity. |
| LLM04 Data and Model Poisoning         | Training or fine-tune data tampering, backdoors, poisoned RAG content, weak data review.                  |
| LLM05 Improper Output Handling         | LLM output passed to HTML, SQL, shell, code, files, URLs, or APIs without validation and encoding.        |
| LLM06 Excessive Agency                 | Over-broad tools, permissions, autonomy, irreversible actions without approval, weak audit logs.          |
| LLM07 System Prompt Leakage            | Secrets or policy in prompts, prompt extraction, guardrails enforced only by prompt text.                 |
| LLM08 Vector and Embedding Weaknesses  | Tenant isolation, permission-aware retrieval, document validation, embedding inversion or leakage.        |
| LLM09 Misinformation                   | Missing grounding, citation checks, confidence handling, human review for high-impact output.             |
| LLM10 Unbounded Consumption            | Token, rate, cost, concurrency, recursion, and model theft controls.                                      |

### 5. Severity and finding format

Severity: Critical means remote or unauthenticated high-impact exploit such as RCE, auth bypass, mass data exposure, or full privilege escalation. Warning means exploitable with preconditions or authentication and bounded impact. Observation means defence-in-depth, weak evidence, or no viable exploit path. Do not mark Critical or Warning without a viable exploit path.

Use this format for each finding:

```markdown
### <Severity>: <Title>

- CWE/OWASP: <required>
- Location: <file:line>
- Confidence: Confirmed / Probable / Unverified
- Source to sink: <source -> controls -> sink>
- Exploit path: <steps an attacker can take>
- Impact: <data theft / RCE / privilege escalation / DoS / information leak>
- Evidence: <code, command output, or trace>
- Fix: <specific code or config change>
```

Write the aggregated report to `CODE-SEC-AUDIT.md` in the project root with
sections for scope and assumptions, checks run and limitations, findings by
severity, repeat-offender patterns, and a prioritised remediation roadmap.
