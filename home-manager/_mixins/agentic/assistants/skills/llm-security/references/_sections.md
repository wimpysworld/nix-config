# Sections

This file defines all sections, their ordering, impact levels, and descriptions.
The section ID (in parentheses) is the filename prefix used to group rules.

Based on the OWASP Top 10 for Large Language Model Applications 2025.

---

## Critical Impact

### 1. Prompt Injection (prompt-injection)

**Impact:** CRITICAL
**Description:** Prevents direct and indirect prompt manipulation through input validation, external content segregation, output filtering, and privilege separation. OWASP LLM01.

### 2. Sensitive Information Disclosure (sensitive-disclosure)

**Impact:** CRITICAL
**Description:** Protects sensitive data through data sanitization before training, output filtering for sensitive patterns, permission-aware RAG systems, and no secrets in system prompts. OWASP LLM02.

### 3. Supply Chain (supply-chain)

**Impact:** CRITICAL
**Description:** Secures the LLM supply chain through model verification and integrity checks, safe model loading (safetensors vs pickle), dependency management with pinning, and ML Bill of Materials (ML-BOM). OWASP LLM03.

### 4. Data and Model Poisoning (data-poisoning)

**Impact:** CRITICAL
**Description:** Prevents data poisoning through training data validation, poisoning indicator detection, data version control, and anomaly detection during training. OWASP LLM04.

### 5. Improper Output Handling (output-handling)

**Impact:** CRITICAL
**Description:** Secures output handling through context-aware encoding (HTML, SQL, shell), parameterized queries for database operations, URL validation and allowlisting, and Content Security Policy. OWASP LLM05.

---

## High Impact

### 6. Excessive Agency (excessive-agency)

**Impact:** HIGH
**Description:** Controls LLM agency through minimizing tool functionality, least privilege permissions, human-in-the-loop for high-impact actions, and rate limiting and audit logging. OWASP LLM06.

### 7. System Prompt Leakage (system-prompt-leakage)

**Impact:** HIGH
**Description:** Prevents prompt leakage through no secrets in system prompts, external guardrails (not prompt-based), input filtering for extraction attempts, and security logic in code, not prompts. OWASP LLM07.

### 8. Vector and Embedding Weaknesses (vector-embedding)

**Impact:** HIGH
**Description:** Secures RAG systems through permission-aware vector retrieval, multi-tenant data isolation, document validation before embedding, and embedding inversion protection. OWASP LLM08.

### 9. Misinformation (misinformation)

**Impact:** HIGH
**Description:** Mitigates misinformation through Retrieval-Augmented Generation (RAG), fact verification pipelines, domain-specific validation, and confidence scoring and disclaimers. OWASP LLM09.

### 10. Unbounded Consumption (unbounded-consumption)

**Impact:** HIGH
**Description:** Controls resource consumption through input validation and size limits, multi-tier rate limiting, budget controls and cost tracking, and model theft detection. OWASP LLM10.

---

## Quick Reference Matrix

| # | Category | Filename | Impact |
|---|----------|----------|--------|
| 1 | Prompt Injection | prompt-injection.md | CRITICAL |
| 2 | Sensitive Disclosure | sensitive-disclosure.md | CRITICAL |
| 3 | Supply Chain | supply-chain.md | CRITICAL |
| 4 | Data Poisoning | data-poisoning.md | CRITICAL |
| 5 | Output Handling | output-handling.md | CRITICAL |
| 6 | Excessive Agency | excessive-agency.md | HIGH |
| 7 | System Prompt Leakage | system-prompt-leakage.md | HIGH |
| 8 | Vector/Embedding | vector-embedding.md | HIGH |
| 9 | Misinformation | misinformation.md | HIGH |
| 10 | Unbounded Consumption | unbounded-consumption.md | HIGH |

---

## Related Frameworks

- **MITRE ATLAS** - Adversarial Threat Landscape for AI Systems
- **NIST AI RMF** - AI Risk Management Framework
- **OWASP ASVS** - Application Security Verification Standard
- **CWE** - Common Weakness Enumeration

## References

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/)
- [MITRE ATLAS](https://atlas.mitre.org/)
- [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework)
