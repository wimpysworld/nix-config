---
title: LLM09 - Mitigate Misinformation and Hallucinations
impact: HIGH
impactDescription: False information leading to wrong decisions, legal liability, or user harm
tags: security, llm, hallucination, misinformation, accuracy, owasp-llm09
---

## LLM09: Mitigate Misinformation and Hallucinations

Misinformation occurs when LLMs generate false or misleading information that appears credible. This includes hallucinations (fabricated facts), unsupported claims, and misrepresentation of expertise. The impact ranges from user harm to legal liability, as seen in cases involving fabricated legal citations and incorrect medical advice.

**Key principle:** Never rely solely on LLM output for critical decisions - implement verification mechanisms.

---

### Retrieval-Augmented Generation (RAG)

**Vulnerable (no grounding):**

```python
def answer_question(query: str) -> str:
    # Pure LLM generation - prone to hallucination
    return llm.generate(f"Answer this question: {query}")
```

**Secure (RAG with source verification):**

```python
from typing import Optional

class GroundedAnswerGenerator:
    """Generate answers grounded in verified sources."""

    def __init__(self, llm, vector_store, min_relevance: float = 0.7):
        self.llm = llm
        self.vector_store = vector_store
        self.min_relevance = min_relevance

    def answer(self, query: str, user_context: dict) -> dict:
        """Generate grounded answer with sources."""

        # Retrieve relevant documents
        docs = self.vector_store.search(
            query=query,
            user_id=user_context["user_id"],
            k=5
        )

        # Filter by relevance threshold
        relevant_docs = [
            d for d in docs
            if d["relevance"] >= self.min_relevance
        ]

        if not relevant_docs:
            return {
                "answer": "I don't have enough information to answer that question accurately.",
                "sources": [],
                "confidence": "low"
            }

        # Build context from sources
        context = "\n\n".join([
            f"Source [{i+1}] ({d['source']}): {d['content']}"
            for i, d in enumerate(relevant_docs)
        ])

        # Generate grounded response
        prompt = f"""Answer the question based ONLY on the provided sources.
If the sources don't contain the answer, say "I don't have information about that."
Always cite sources using [1], [2], etc.

Sources:
{context}

Question: {query}

Answer:"""

        response = self.llm.generate(prompt)

        return {
            "answer": response,
            "sources": [d["source"] for d in relevant_docs],
            "confidence": self._assess_confidence(response, relevant_docs)
        }

    def _assess_confidence(self, response: str, docs: list) -> str:
        """Assess confidence based on source coverage."""
        citation_count = len(re.findall(r'\[\d+\]', response))

        if citation_count >= 2 and len(docs) >= 3:
            return "high"
        elif citation_count >= 1:
            return "medium"
        else:
            return "low"
```

---

### Fact Verification Pipeline

**Implementation:**

```python
from dataclasses import dataclass
from typing import List, Optional
from enum import Enum

class VerificationStatus(Enum):
    VERIFIED = "verified"
    UNVERIFIED = "unverified"
    CONTRADICTED = "contradicted"
    UNCERTAIN = "uncertain"

@dataclass
class FactClaim:
    claim: str
    source: Optional[str]
    verification_status: VerificationStatus
    confidence: float

class FactVerifier:
    """Verify factual claims in LLM output."""

    def __init__(self, knowledge_base, verification_llm):
        self.kb = knowledge_base
        self.verifier = verification_llm

    def extract_claims(self, text: str) -> List[str]:
        """Extract factual claims from text."""
        prompt = f"""Extract all factual claims from this text.
Return each claim on a new line.

Text: {text}

Claims:"""
        response = self.verifier.generate(prompt)
        return [c.strip() for c in response.split('\n') if c.strip()]

    def verify_claim(self, claim: str) -> FactClaim:
        """Verify a single claim against knowledge base."""

        # Search for supporting evidence
        evidence = self.kb.search(claim, k=3)

        if not evidence:
            return FactClaim(
                claim=claim,
                source=None,
                verification_status=VerificationStatus.UNVERIFIED,
                confidence=0.0
            )

        # Use LLM to assess evidence
        prompt = f"""Does the evidence support or contradict this claim?

Claim: {claim}

Evidence:
{chr(10).join([e['content'] for e in evidence])}

Answer with: SUPPORTS, CONTRADICTS, or UNCERTAIN
Then explain briefly."""

        assessment = self.verifier.generate(prompt)

        if "SUPPORTS" in assessment.upper():
            status = VerificationStatus.VERIFIED
            confidence = 0.8
        elif "CONTRADICTS" in assessment.upper():
            status = VerificationStatus.CONTRADICTED
            confidence = 0.8
        else:
            status = VerificationStatus.UNCERTAIN
            confidence = 0.5

        return FactClaim(
            claim=claim,
            source=evidence[0]["source"],
            verification_status=status,
            confidence=confidence
        )

    def verify_response(self, response: str) -> dict:
        """Verify all claims in an LLM response."""
        claims = self.extract_claims(response)
        verified_claims = [self.verify_claim(c) for c in claims]

        return {
            "original_response": response,
            "claims": verified_claims,
            "overall_reliability": self._calculate_reliability(verified_claims)
        }

    def _calculate_reliability(self, claims: List[FactClaim]) -> str:
        if not claims:
            return "unknown"

        verified_count = sum(
            1 for c in claims
            if c.verification_status == VerificationStatus.VERIFIED
        )
        contradicted_count = sum(
            1 for c in claims
            if c.verification_status == VerificationStatus.CONTRADICTED
        )

        if contradicted_count > 0:
            return "unreliable"
        elif verified_count / len(claims) > 0.7:
            return "reliable"
        else:
            return "partially_verified"
```

---

### Output Validation for Critical Domains

**Implementation:**

```python
class DomainSpecificValidator:
    """Domain-specific validation for critical outputs."""

    def __init__(self, domain: str):
        self.domain = domain
        self.validators = {
            "medical": self._validate_medical,
            "legal": self._validate_legal,
            "financial": self._validate_financial,
        }

    def validate(self, response: str) -> dict:
        validator = self.validators.get(self.domain)
        if validator:
            return validator(response)
        return {"valid": True, "warnings": []}

    def _validate_medical(self, response: str) -> dict:
        """Validate medical information."""
        warnings = []

        # Check for diagnosis patterns
        if re.search(r"you (have|might have|likely have)", response, re.I):
            warnings.append(
                "Response may contain diagnostic claims. "
                "Add disclaimer about consulting healthcare provider."
            )

        # Check for treatment recommendations
        if re.search(r"you should (take|use|try)", response, re.I):
            warnings.append(
                "Response contains treatment suggestions. "
                "Ensure disclaimer is present."
            )

        # Required disclaimer check
        required_disclaimer = "not a substitute for professional medical advice"
        if not re.search(required_disclaimer, response, re.I):
            warnings.append("Missing medical disclaimer")

        return {
            "valid": len(warnings) == 0,
            "warnings": warnings
        }

    def _validate_legal(self, response: str) -> dict:
        """Validate legal information."""
        warnings = []

        # Check for case citations - must be verifiable
        citations = re.findall(r'\d+\s+[A-Z][a-z]+\.?\s+\d+', response)
        if citations:
            warnings.append(
                f"Response contains legal citations that must be verified: {citations}"
            )

        # Check for legal advice patterns
        if re.search(r"you should (sue|file|claim)", response, re.I):
            warnings.append("Response may constitute legal advice")

        required_disclaimer = "not legal advice"
        if not re.search(required_disclaimer, response, re.I):
            warnings.append("Missing legal disclaimer")

        return {
            "valid": len(warnings) == 0,
            "warnings": warnings
        }

    def _validate_financial(self, response: str) -> dict:
        """Validate financial information."""
        warnings = []

        # Check for investment advice
        if re.search(r"you should (buy|sell|invest)", response, re.I):
            warnings.append("Response may constitute investment advice")

        # Check for price predictions
        if re.search(r"(will|going to) (rise|fall|increase|decrease)", response, re.I):
            warnings.append("Response contains price predictions")

        return {
            "valid": len(warnings) == 0,
            "warnings": warnings
        }
```

---

### Confidence Scoring and Disclaimers

**Implementation:**

```python
class ConfidenceAwareResponder:
    """Generate responses with confidence indicators."""

    DISCLAIMERS = {
        "medical": "This information is for educational purposes only and "
                   "is not a substitute for professional medical advice.",
        "legal": "This is general information and should not be "
                 "construed as legal advice.",
        "financial": "This is not financial advice. Consult a qualified "
                     "professional before making investment decisions.",
        "general": "AI-generated responses may contain errors. "
                   "Please verify important information independently."
    }

    def __init__(self, llm, knowledge_base):
        self.llm = llm
        self.kb = knowledge_base

    def generate_response(
        self,
        query: str,
        domain: str = "general"
    ) -> dict:
        """Generate response with confidence scoring."""

        # Get grounded response
        docs = self.kb.search(query, k=5)
        response = self._generate_with_sources(query, docs)

        # Calculate confidence
        confidence_score = self._calculate_confidence(query, response, docs)

        # Add appropriate disclaimer
        disclaimer = self.DISCLAIMERS.get(domain, self.DISCLAIMERS["general"])

        # Format confidence for user
        if confidence_score >= 0.8:
            confidence_label = "High confidence"
        elif confidence_score >= 0.5:
            confidence_label = "Medium confidence"
        else:
            confidence_label = "Low confidence - please verify"

        return {
            "response": response,
            "confidence_score": confidence_score,
            "confidence_label": confidence_label,
            "disclaimer": disclaimer,
            "sources": [d["source"] for d in docs[:3]]
        }

    def _calculate_confidence(
        self,
        query: str,
        response: str,
        sources: list
    ) -> float:
        """Calculate confidence based on multiple factors."""
        score = 0.5  # Base score

        # Factor 1: Source coverage
        if len(sources) >= 3:
            score += 0.2
        elif len(sources) >= 1:
            score += 0.1

        # Factor 2: Source relevance
        avg_relevance = sum(s.get("relevance", 0) for s in sources) / max(len(sources), 1)
        score += avg_relevance * 0.2

        # Factor 3: Response includes citations
        if re.search(r'\[\d+\]', response):
            score += 0.1

        return min(score, 1.0)
```

---

### User Education and Transparency

**Implementation:**

```python
class TransparentLLMInterface:
    """Interface that educates users about LLM limitations."""

    def __init__(self, llm_service):
        self.service = llm_service
        self.shown_disclaimer = set()

    def process_query(self, user_id: str, query: str) -> dict:
        """Process query with transparency measures."""

        response_data = self.service.generate_response(query)

        # First-time user education
        educational_note = None
        if user_id not in self.shown_disclaimer:
            educational_note = """Important: This AI assistant can make mistakes.
- Verify important information from authoritative sources
- Don't rely on AI for medical, legal, or financial decisions
- The AI may produce plausible-sounding but incorrect information"""
            self.shown_disclaimer.add(user_id)

        return {
            "response": response_data["response"],
            "confidence": response_data["confidence_label"],
            "sources": response_data.get("sources", []),
            "disclaimer": response_data["disclaimer"],
            "educational_note": educational_note,
            "metadata": {
                "is_ai_generated": True,
                "model_version": "gpt-4-2024",
                "grounded": bool(response_data.get("sources"))
            }
        }
```

---

### Key Prevention Rules

1. **Use RAG** - Ground responses in verified knowledge sources
2. **Verify facts** - Implement fact-checking for critical claims
3. **Domain validation** - Apply domain-specific checks for medical/legal/financial
4. **Show confidence** - Display confidence scores and uncertainty indicators
5. **Add disclaimers** - Include appropriate warnings for sensitive domains
6. **Cite sources** - Always provide sources for factual claims
7. **Educate users** - Help users understand LLM limitations
8. **Human oversight** - Require review for high-stakes outputs

**References:**
- [OWASP LLM09:2025 Misinformation](https://genai.owasp.org/llmrisk/llm09-misinformation/)
- [Reducing LLM Hallucinations](https://www.anthropic.com/news/reducing-hallucination)
- [RAG for Grounded Generation](https://arxiv.org/abs/2005.11401)
