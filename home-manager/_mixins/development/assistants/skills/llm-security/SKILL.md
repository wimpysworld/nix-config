---
name: llm-security
description: "Security guidelines for LLM applications based on OWASP Top 10 for LLM 2025. Use when building LLM apps, reviewing AI security, implementing RAG systems, or asking about LLM vulnerabilities like 'prompt injection' or 'check LLM security'. IMPORTANT: Always consult this skill when building chatbots, AI agents, RAG pipelines, tool-using LLMs, agentic systems, or any application that calls an LLM API (OpenAI, Anthropic, Gemini, etc.) — even if the user doesn't explicitly mention security. Also use when users import 'openai', 'anthropic', 'langchain', 'llamaindex', or similar LLM libraries."
---

# LLM Security Guidelines (OWASP Top 10 for LLM 2025)

Security rules for building secure LLM applications, based on the OWASP Top 10 for LLM Applications 2025.

## How to Use This Skill

**Proactive mode** — When building or reviewing LLM applications, automatically check for relevant security risks based on the application pattern. You don't need to wait for the user to ask about LLM security.

**Reactive mode** — When the user asks about LLM security, use the mapping below to find relevant rule files with detailed vulnerable/secure code examples.

### Workflow
1. Identify what the user is building (see "What Are You Building?" below)
2. Check the priority rules for that pattern
3. Read the specific rule files from `references/` for code examples
4. Apply the secure patterns or flag vulnerable ones

## What Are You Building?

Use this to quickly identify which rules matter most for the user's task:

| Building... | Priority Rules |
|-------------|---------------|
| **Chatbot / conversational AI** | Prompt Injection (LLM01), System Prompt Leakage (LLM07), Output Handling (LLM05), Unbounded Consumption (LLM10) |
| **RAG system** | Vector/Embedding Weaknesses (LLM08), Prompt Injection (LLM01), Sensitive Disclosure (LLM02), Misinformation (LLM09) |
| **AI agent with tools** | Excessive Agency (LLM06), Prompt Injection (LLM01), Output Handling (LLM05), Sensitive Disclosure (LLM02) |
| **Fine-tuning / training** | Data Poisoning (LLM04), Supply Chain (LLM03), Sensitive Disclosure (LLM02) |
| **LLM-powered API** | Unbounded Consumption (LLM10), Prompt Injection (LLM01), Output Handling (LLM05), Sensitive Disclosure (LLM02) |
| **Content generation** | Misinformation (LLM09), Output Handling (LLM05), Prompt Injection (LLM01) |

## Categories

### Critical Impact
- **LLM01: Prompt Injection** (`references/prompt-injection.md`) - Prevent direct and indirect prompt manipulation
- **LLM02: Sensitive Information Disclosure** (`references/sensitive-disclosure.md`) - Protect PII, credentials, and proprietary data
- **LLM03: Supply Chain** (`references/supply-chain.md`) - Secure model sources, training data, and dependencies
- **LLM04: Data and Model Poisoning** (`references/data-poisoning.md`) - Prevent training data manipulation and backdoors
- **LLM05: Improper Output Handling** (`references/output-handling.md`) - Sanitise LLM outputs before downstream use

### High Impact
- **LLM06: Excessive Agency** (`references/excessive-agency.md`) - Limit LLM permissions, functionality, and autonomy
- **LLM07: System Prompt Leakage** (`references/system-prompt-leakage.md`) - Protect system prompts from disclosure
- **LLM08: Vector and Embedding Weaknesses** (`references/vector-embedding.md`) - Secure RAG systems and embeddings
- **LLM09: Misinformation** (`references/misinformation.md`) - Mitigate hallucinations and false outputs
- **LLM10: Unbounded Consumption** (`references/unbounded-consumption.md`) - Prevent DoS, cost attacks, and model theft

See `references/_sections.md` for the full index with OWASP/MITRE references.

## Quick Reference

| Vulnerability | Key Prevention |
|--------------|----------------|
| Prompt Injection | Input validation, output filtering, privilege separation |
| Sensitive Disclosure | Data sanitisation, access controls, encryption |
| Supply Chain | Verify models, SBOM, trusted sources only |
| Data Poisoning | Data validation, anomaly detection, sandboxing |
| Output Handling | Treat LLM as untrusted, encode outputs, parameterise queries |
| Excessive Agency | Least privilege, human-in-the-loop, minimise extensions |
| System Prompt Leakage | No secrets in prompts, external guardrails |
| Vector/Embedding | Access controls, data validation, monitoring |
| Misinformation | RAG, fine-tuning, human oversight, cross-verification |
| Unbounded Consumption | Rate limiting, input validation, resource monitoring |

## Key Principles

1. **Never trust LLM output** - Validate and sanitise all outputs before use
2. **Least privilege** - Grant minimum necessary permissions to LLM systems
3. **Defence in depth** - Layer multiple security controls
4. **Human oversight** - Require approval for high-impact actions
5. **Monitor and log** - Track all LLM interactions for anomaly detection

## References

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/)
- [MITRE ATLAS - Adversarial Threat Landscape for AI Systems](https://atlas.mitre.org/)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
