---
name: code-security
description: "Security guidelines for writing secure code. Use when writing code, reviewing code for vulnerabilities, or asking about secure coding practices like 'check for SQL injection' or 'review security'. IMPORTANT: Always consult this skill when writing or reviewing any code that handles user input, authentication, file operations, database queries, network requests, cryptography, or infrastructure configuration (Terraform, Kubernetes, Docker, GitHub Actions) — even if the user doesn't explicitly mention security. Also use when users ask to 'review my code', 'check this for bugs', or 'is this safe'."
---

# Code Security Guidelines

Comprehensive security rules for writing secure code across 15+ languages. Covers OWASP Top 10, infrastructure security, and coding best practices with 28 rule categories.

## How to Use This Skill

**Proactive mode** — When writing or reviewing code, automatically check for relevant vulnerabilities based on the language and patterns present. You don't need to wait for the user to ask about security.

**Reactive mode** — When the user asks about security, use the categories below to find the relevant rule file, then read it for detailed vulnerable/secure code examples.

### Workflow
1. Identify the language and what the code does (handles input? queries a DB? reads files?)
2. Check the relevant rules below — focus on Critical and High impact first
3. Read the specific rule file from `references/` for detailed code examples in that language
4. Apply the secure patterns, or flag the vulnerable patterns if reviewing

## Language-Specific Priority Rules

When writing code in these languages, check these rules first:

| Language | Priority Rules to Check |
|----------|------------------------|
| **Python** | SQL injection, command injection, path traversal, code injection, SSRF, insecure crypto |
| **JavaScript/TypeScript** | XSS, prototype pollution, code injection, insecure transport, CSRF |
| **Java** | SQL injection, XXE, insecure deserialization, insecure crypto, SSRF |
| **Go** | SQL injection, command injection, path traversal, insecure transport |
| **C/C++** | Memory safety, unsafe functions, command injection, path traversal |
| **Ruby** | SQL injection, command injection, code injection, insecure deserialization |
| **PHP** | SQL injection, XSS, command injection, code injection, path traversal |
| **HCL/YAML** | Terraform (AWS/Azure/GCP), Kubernetes, Docker, GitHub Actions |

## Categories

### Critical Impact
- **SQL Injection** (`references/sql-injection.md`) - Use parameterized queries, never concatenate user input
- **Command Injection** (`references/command-injection.md`) - Avoid shell commands with user input, use safe APIs
- **XSS** (`references/xss.md`) - Escape output, use framework protections
- **XXE** (`references/xxe.md`) - Disable external entities in XML parsers
- **Path Traversal** (`references/path-traversal.md`) - Validate and sanitize file paths
- **Insecure Deserialization** (`references/insecure-deserialization.md`) - Never deserialize untrusted data
- **Code Injection** (`references/code-injection.md`) - Never eval() user input
- **Hardcoded Secrets** (`references/secrets.md`) - Use environment variables or secret managers
- **Memory Safety** (`references/memory-safety.md`) - Prevent buffer overflows, use-after-free (C/C++)

### High Impact
- **Insecure Crypto** (`references/insecure-crypto.md`) - Use SHA-256+, AES-256, avoid MD5/SHA1/DES
- **Insecure Transport** (`references/insecure-transport.md`) - Use HTTPS, verify certificates
- **SSRF** (`references/ssrf.md`) - Validate URLs, use allowlists
- **JWT Issues** (`references/authentication-jwt.md`) - Always verify signatures
- **CSRF** (`references/csrf.md`) - Use CSRF tokens on state-changing requests
- **Prototype Pollution** (`references/prototype-pollution.md`) - Validate object keys in JavaScript

### Infrastructure
- **Terraform AWS/Azure/GCP** (`references/terraform-aws.md`, `references/terraform-azure.md`, `references/terraform-gcp.md`) - Encryption, least privilege, no public access
- **Kubernetes** (`references/kubernetes.md`) - No privileged containers, run as non-root
- **Docker** (`references/docker.md`) - Don't run as root, pin image versions
- **GitHub Actions** (`references/github-actions.md`) - Avoid script injection, pin action versions

### Medium/Low Impact
- **Regex DoS** (`references/regex-dos.md`) - Avoid catastrophic backtracking
- **Race Conditions** (`references/race-condition.md`) - Use proper synchronization
- **Correctness** (`references/correctness.md`) - Avoid common logic bugs
- **Best Practices** (`references/best-practice.md`) - General secure coding patterns

See `references/_sections.md` for the full index with CWE/OWASP references.

## Quick Reference

| Vulnerability | Key Prevention |
|--------------|----------------|
| SQL Injection | Parameterized queries |
| XSS | Output encoding |
| Command Injection | Avoid shell, use APIs |
| Path Traversal | Validate paths |
| SSRF | URL allowlists |
| Secrets | Environment variables |
| Crypto | SHA-256, AES-256 |
