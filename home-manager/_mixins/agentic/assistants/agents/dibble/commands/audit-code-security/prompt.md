## Code Security Audit

Run a full-project code security audit. Take no arguments. Use wide sub-agent fan-out and write only `CODE-SEC-AUDIT.md` in the project root.

### Operating rules

1. Delegate to many sub-agents, in parallel where useful. Split by directory, concern, language, or attack surface. Exclude git submodules. The parent aggregates findings.
2. Ask only when the audit scope or threat model is unclear.
3. This command may read source files, run the Bash checks below, and write `CODE-SEC-AUDIT.md`. Do not edit source files or stage changes.
4. Default threat model: an external unauthenticated attacker. Record any different assumption.

### Method

- Identify stack, deployment surface, trust boundaries, auth model, secrets stores, data classes, and prior security notes.
- Map sources: HTTP, webhooks, CLI args, queues, jobs, uploads, files, env/config, third-party callbacks, LLM prompts, RAG documents, and tool results.
- Map sinks: database queries, OS commands, file paths, templates/HTML, redirects, outbound URLs, deserialisation, auth/authz decisions, logs, crypto, secrets, model calls, and tool calls.
- Trace source to sink. A finding needs a controllable source, reachable sink, missing or weak control, and impact. Prioritise language-specific risks across injection, auth, files, network, parsers, crypto, memory safety, and infrastructure config.

### Automated checks

Run available checks in this order: SAST, secrets, dependencies, then ecosystem audits. Record missing tools or skipped scopes.

```bash
semgrep --config p/security-audit --config p/owasp-top-ten --config p/cwe-top-25 .
gitleaks detect --source . --report-format json
gitleaks git --source . --report-format json
osv-scanner scan --recursive .
```

Also run native audits when the manifest and tool exist: `npm audit`, `pnpm audit`, `yarn npm audit`, `pip-audit`, `bundle audit`, `cargo audit`, `govulncheck ./...`, and `composer audit`.
Triage every result. Report confirmed true positives. Dismiss false positives with a short reason. For secrets, never print the value. Report type, path, line, fingerprint or prefix, exposure in working tree or history, and required rotation. Treat git history secrets as exposed. For dependencies, record package manager, package, installed version, advisory ID, severity, exploitability, and fixed version.

### Manual checklist

| Area | Check |
| --- | --- |
| Auth, sessions, access | Missing authn/authz, IDOR, tenant isolation, role confusion, session flaws, JWT signature/expiry, CSRF. |
| Injection, parsers, files | SQL/NoSQL, OS command, code/eval, template, LDAP, XML/XXE, unsafe deserialisation, prototype pollution, path traversal, uploads, archive slip, temp files, MIME/type checks. |
| Web output | XSS, open redirect, CORS, CSP, security headers, cookie flags, context-aware encoding. |
| Network | SSRF, webhook trust, outbound allowlists, TLS verification, timeouts, cleartext transport. |
| Secrets, crypto, deps, CI | Hardcoded secrets, weak random/hash/cipher, key storage, rotation, sensitive logs, unpinned deps/actions/images, postinstall scripts, typosquatting, unsafe PR workflows. |
| Infrastructure and resources | Terraform/cloud public access, IAM least privilege, Kubernetes privileged pods/RBAC, Docker root/socket/secrets, rate limits, request size, pagination, regex DoS, memory/CPU bounds, queue back-pressure. |
| Native, race, logic | Buffer overflow, use-after-free, integer overflow, unsafe functions, FFI boundaries, TOCTOU, replay, double spend, client-side price/role trust, workflow order bypass, batch amplification. |

### LLM app checks, conditional

Run this section only when the target uses LLMs, RAG, agents, tools, embeddings, model APIs, or libraries such as `openai`, `anthropic`, `langchain`, `llamaindex`, `transformers`, `litellm`, `mistralai`, or `google-generativeai`. Otherwise state `No LLM surface found` and skip it.

First classify the surface: chatbot, RAG, tool-using agent, fine-tuning/training, LLM API, or content generation. Treat LLM input, retrieved content, tool results, and model output as untrusted.

| OWASP LLM 2025 | Check |
| --- | --- |
| LLM01 Prompt Injection | Direct and indirect injection from users, retrieved content, files, websites, emails, or tool results. |
| LLM02 Sensitive Information Disclosure | PII, credentials, secrets, proprietary data in prompts, context, logs, responses, training data, or RAG. |
| LLM03 Supply Chain | Model provenance, pinned model versions, safe model loading, trusted plugins/tools, dependency integrity, ML-BOM. |
| LLM04 Data and Model Poisoning | Training/fine-tune data tampering, backdoors, poisoned RAG content, weak data review. |
| LLM05 Improper Output Handling | LLM output passed to HTML, SQL, shell, code, files, URLs, or APIs without validation and encoding. |
| LLM06 Excessive Agency | Over-broad tools, permissions, autonomy, irreversible actions without approval, weak audit logs. |
| LLM07 System Prompt Leakage | Secrets or policy in prompts, prompt extraction, guardrails enforced only by prompt text. |
| LLM08 Vector and Embedding Weaknesses | Tenant isolation, permission-aware retrieval, document validation, embedding inversion or leakage. |
| LLM09 Misinformation | Missing grounding, citation checks, confidence handling, human review for high-impact output. |
| LLM10 Unbounded Consumption | Token, rate, cost, concurrency, recursion, and model theft controls. |

### Severity and finding format

Severity: Critical means unauthenticated or remote RCE, auth bypass, mass data exposure, or full privilege escalation. High means a confirmed exploit path with high impact or privileged chaining. Medium means preconditions, authentication, or bounded impact. Low means a plausible low-impact flaw. Observation means defence-in-depth, weak evidence, or no viable exploit path. Do not mark Critical, High, Medium, or Low without a viable exploit path. Write `CODE-SEC-AUDIT.md` with scope and assumptions, checks run and limitations, findings by severity, repeat-offender patterns, and a prioritised remediation roadmap.

```markdown
### <Severity>: <Title>
- CWE/OWASP: <required>
- Location: <file:line>
- Confidence: Confirmed / Probable / Unverified
- Source to sink: <source -> controls -> sink>
- Exploit path: <steps an attacker can take>
- Impact: <data theft / RCE / privilege escalation / DoS / information leak>
- Evidence: <redacted code, command output, or trace>
- Fix: <specific code or config change>
```
