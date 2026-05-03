# Sections

This file defines all sections, their ordering, impact levels, and descriptions.
The section ID (in parentheses) is the filename prefix used to group rules.

---

## Critical Impact

### 1. SQL Injection (sql-injection)

**Impact:** CRITICAL
**Description:** SQL injection allows attackers to manipulate database queries, leading to data theft, modification, or deletion. OWASP Top 10.

### 2. Command Injection (command-injection)

**Impact:** CRITICAL
**Description:** OS command injection allows attackers to execute arbitrary system commands, leading to full system compromise. CWE-78.

### 3. Cross-Site Scripting (xss)

**Impact:** CRITICAL
**Description:** XSS allows attackers to inject malicious scripts into web pages, leading to session hijacking, defacement, or malware distribution. CWE-79.

### 4. XML External Entity (xxe)

**Impact:** CRITICAL
**Description:** XXE attacks exploit XML parsers to access local files, perform SSRF, or cause denial of service. CWE-611.

### 5. Path Traversal (path-traversal)

**Impact:** CRITICAL
**Description:** Path traversal allows attackers to access files outside intended directories using sequences like "../". CWE-22.

### 6. Insecure Deserialization (insecure-deserialization)

**Impact:** CRITICAL
**Description:** Deserializing untrusted data can lead to remote code execution, DoS, or authentication bypass. CWE-502.

### 7. Code Injection (code-injection)

**Impact:** CRITICAL
**Description:** Code injection (eval, template injection) allows attackers to execute arbitrary code in the application context. CWE-94.

### 8. Hardcoded Secrets (secrets)

**Impact:** CRITICAL
**Description:** Hardcoded credentials, API keys, and tokens in source code lead to unauthorized access when code is exposed. CWE-798.

### 9. Memory Safety (memory-safety)

**Impact:** CRITICAL
**Description:** Memory safety issues (buffer overflow, use-after-free) can lead to code execution or crashes. CWE-119, CWE-416.

---

## High Impact

### 10. Insecure Cryptography (insecure-crypto)

**Impact:** HIGH
**Description:** Weak hashing (MD5, SHA1), weak encryption (DES, RC4), or improper key management compromises data confidentiality. CWE-327.

### 11. Insecure Transport (insecure-transport)

**Impact:** HIGH
**Description:** Cleartext transmission, disabled certificate verification, or weak TLS exposes data in transit. CWE-319.

### 12. Server-Side Request Forgery (ssrf)

**Impact:** HIGH
**Description:** SSRF allows attackers to make requests from the server to internal systems or cloud metadata endpoints. CWE-918.

### 13. JWT Authentication (authentication-jwt)

**Impact:** HIGH
**Description:** JWT vulnerabilities include the "none" algorithm attack, weak secrets, and missing signature verification. CWE-347.

### 14. Cross-Site Request Forgery (csrf)

**Impact:** HIGH
**Description:** CSRF attacks force authenticated users to perform unwanted actions without their knowledge. CWE-352.

### 15. Prototype Pollution (prototype-pollution)

**Impact:** HIGH
**Description:** Prototype pollution in JavaScript can lead to property injection, denial of service, or code execution. CWE-1321.

### 16. Unsafe Functions (unsafe-functions)

**Impact:** HIGH
**Description:** Inherently dangerous functions (gets, strcpy, eval) bypass safety checks and should be avoided. CWE-242.

### 17. Terraform AWS Security (terraform-aws)

**Impact:** HIGH
**Description:** AWS infrastructure misconfigurations including public S3 buckets, unencrypted resources, and overly permissive IAM.

### 18. Terraform Azure Security (terraform-azure)

**Impact:** HIGH
**Description:** Azure infrastructure misconfigurations including public endpoints, missing encryption, and insecure network settings.

### 19. Terraform GCP Security (terraform-gcp)

**Impact:** HIGH
**Description:** GCP infrastructure misconfigurations including public resources, disabled logging, and insecure IAM bindings.

### 20. Kubernetes Security (kubernetes)

**Impact:** HIGH
**Description:** Kubernetes misconfigurations including privileged containers, host namespace access, and excessive RBAC permissions.

### 21. Docker Security (docker)

**Impact:** HIGH
**Description:** Docker misconfigurations including running as root, privileged mode, and exposed Docker socket.

### 22. GitHub Actions Security (github-actions)

**Impact:** HIGH
**Description:** GitHub Actions vulnerabilities including script injection, unsafe checkout of PR code, and unpinned actions.

---

## Medium Impact

### 23. Regular Expression DoS (regex-dos)

**Impact:** MEDIUM
**Description:** ReDoS attacks exploit inefficient regex patterns to cause CPU exhaustion and denial of service. CWE-1333.

### 24. Race Conditions (race-condition)

**Impact:** MEDIUM
**Description:** TOCTOU race conditions and insecure temporary file creation can lead to privilege escalation. CWE-367.

### 25. Code Correctness (correctness)

**Impact:** MEDIUM
**Description:** Common coding mistakes including exception handling errors, null checks, type errors, and logic bugs.

---

## Low Impact

### 26. Best Practices (best-practice)

**Impact:** LOW
**Description:** Code style, API usage patterns, deprecated patterns, and general coding recommendations.

### 27. Performance (performance)

**Impact:** LOW
**Description:** Performance anti-patterns including inefficient loops, unnecessary database queries, and memory waste.

### 28. Maintainability (maintainability)

**Impact:** LOW
**Description:** Code organization, deprecated API usage, naming conventions, and long-term code health.

---

## Rule File Summary

| # | Category | Filename | Impact |
|---|----------|----------|--------|
| 1 | SQL Injection | sql-injection.md | CRITICAL |
| 2 | Command Injection | command-injection.md | CRITICAL |
| 3 | Cross-Site Scripting | xss.md | CRITICAL |
| 4 | XML External Entity | xxe.md | CRITICAL |
| 5 | Path Traversal | path-traversal.md | CRITICAL |
| 6 | Insecure Deserialization | insecure-deserialization.md | CRITICAL |
| 7 | Code Injection | code-injection.md | CRITICAL |
| 8 | Hardcoded Secrets | secrets.md | CRITICAL |
| 9 | Memory Safety | memory-safety.md | CRITICAL |
| 10 | Insecure Cryptography | insecure-crypto.md | HIGH |
| 11 | Insecure Transport | insecure-transport.md | HIGH |
| 12 | SSRF | ssrf.md | HIGH |
| 13 | JWT Authentication | authentication-jwt.md | HIGH |
| 14 | CSRF | csrf.md | HIGH |
| 15 | Prototype Pollution | prototype-pollution.md | HIGH |
| 16 | Unsafe Functions | unsafe-functions.md | HIGH |
| 17 | Terraform AWS | terraform-aws.md | HIGH |
| 18 | Terraform Azure | terraform-azure.md | HIGH |
| 19 | Terraform GCP | terraform-gcp.md | HIGH |
| 20 | Kubernetes | kubernetes.md | HIGH |
| 21 | Docker | docker.md | HIGH |
| 22 | GitHub Actions | github-actions.md | HIGH |
| 23 | Regex DoS | regex-dos.md | MEDIUM |
| 24 | Race Conditions | race-condition.md | MEDIUM |
| 25 | Correctness | correctness.md | MEDIUM |
| 26 | Best Practices | best-practice.md | LOW |
| 27 | Performance | performance.md | LOW |
| 28 | Maintainability | maintainability.md | LOW |
