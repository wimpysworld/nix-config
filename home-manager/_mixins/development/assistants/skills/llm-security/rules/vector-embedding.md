---
title: LLM08 - Secure Vector and Embedding Systems
impact: HIGH
impactDescription: Data leakage, poisoned retrieval, cross-tenant information exposure
tags: security, llm, rag, embeddings, vector-database, owasp-llm08
---

## LLM08: Secure Vector and Embedding Systems

Vector and embedding vulnerabilities affect Retrieval-Augmented Generation (RAG) systems. Risks include unauthorized access to embeddings containing sensitive data, cross-context information leaks in multi-tenant systems, embedding inversion attacks, and data poisoning through malicious documents.

**Key principle:** Apply the same access controls to vector databases as to source documents.

---

### Permission-Aware Vector Retrieval

**Vulnerable (no access control):**

```python
def search_documents(query: str) -> list[str]:
    # Retrieves from entire database regardless of user permissions
    embedding = embed_model.encode(query)
    results = vector_db.similarity_search(embedding, k=5)
    return [r.content for r in results]
```

**Secure (permission-aware retrieval):**

```python
from typing import Optional

class SecureVectorStore:
    """Vector store with access control enforcement."""

    def __init__(self, vector_db, embed_model):
        self.db = vector_db
        self.embedder = embed_model

    def search(
        self,
        query: str,
        user_id: str,
        user_roles: list[str],
        k: int = 5
    ) -> list[dict]:
        """Search with permission filtering."""

        # Build permission filter
        permission_filter = {
            "$or": [
                {"access_level": "public"},
                {"owner_id": user_id},
                {"allowed_roles": {"$in": user_roles}},
                {"allowed_users": {"$in": [user_id]}}
            ]
        }

        embedding = self.embedder.encode(query)

        # Apply filter at query time
        results = self.db.similarity_search(
            embedding,
            k=k * 2,  # Over-fetch to account for filtering
            filter=permission_filter
        )

        # Double-check permissions (defense in depth)
        authorized_results = []
        for result in results:
            if self._user_authorized(user_id, user_roles, result.metadata):
                authorized_results.append({
                    "content": result.content,
                    "source": result.metadata.get("source"),
                    "relevance": result.score
                })

            if len(authorized_results) >= k:
                break

        return authorized_results

    def _user_authorized(
        self,
        user_id: str,
        user_roles: list[str],
        metadata: dict
    ) -> bool:
        """Verify user authorization for document."""
        access_level = metadata.get("access_level", "private")

        if access_level == "public":
            return True

        if metadata.get("owner_id") == user_id:
            return True

        allowed_roles = set(metadata.get("allowed_roles", []))
        if allowed_roles & set(user_roles):
            return True

        allowed_users = metadata.get("allowed_users", [])
        if user_id in allowed_users:
            return True

        return False
```

---

### Multi-Tenant Data Isolation

**Vulnerable (shared vector space):**

```python
# All tenants share same collection
vector_db = chromadb.Client()
collection = vector_db.create_collection("documents")

def add_document(tenant_id: str, content: str):
    # Documents from all tenants mixed together
    collection.add(
        documents=[content],
        ids=[str(uuid.uuid4())]
    )
```

**Secure (tenant isolation):**

```python
from typing import Dict

class TenantIsolatedVectorStore:
    """Vector store with strict tenant isolation."""

    def __init__(self, db_client):
        self.client = db_client
        self.tenant_collections: Dict[str, any] = {}

    def _get_tenant_collection(self, tenant_id: str):
        """Get or create isolated collection for tenant."""
        if tenant_id not in self.tenant_collections:
            # Validate tenant ID format
            if not re.match(r'^[a-zA-Z0-9_-]+$', tenant_id):
                raise ValueError("Invalid tenant ID format")

            # Create isolated collection
            collection_name = f"tenant_{tenant_id}_docs"
            self.tenant_collections[tenant_id] = \
                self.client.get_or_create_collection(collection_name)

        return self.tenant_collections[tenant_id]

    def add_document(
        self,
        tenant_id: str,
        doc_id: str,
        content: str,
        metadata: dict
    ):
        """Add document to tenant-specific collection."""
        collection = self._get_tenant_collection(tenant_id)

        # Always include tenant_id in metadata for verification
        metadata["tenant_id"] = tenant_id

        collection.add(
            documents=[content],
            ids=[doc_id],
            metadatas=[metadata]
        )

    def search(
        self,
        tenant_id: str,
        query: str,
        k: int = 5
    ) -> list[dict]:
        """Search within tenant's isolated collection only."""
        collection = self._get_tenant_collection(tenant_id)

        results = collection.query(
            query_texts=[query],
            n_results=k
        )

        # Verify results belong to tenant (defense in depth)
        verified_results = []
        for i, doc in enumerate(results['documents'][0]):
            metadata = results['metadatas'][0][i]
            if metadata.get("tenant_id") == tenant_id:
                verified_results.append({
                    "content": doc,
                    "metadata": metadata
                })

        return verified_results
```

---

### Data Validation Before Embedding

**Vulnerable (unvalidated content):**

```python
def index_document(file_path: str):
    content = read_file(file_path)
    # Direct embedding without validation
    embedding = embed_model.encode(content)
    vector_db.add(embedding, content)
```

**Secure (validated content):**

```python
import re
from typing import Tuple

class DocumentValidator:
    """Validate documents before embedding."""

    def __init__(self):
        self.max_content_length = 50000
        self.min_content_length = 10

    def validate(self, content: str, metadata: dict) -> Tuple[bool, list[str]]:
        """Validate document content and metadata."""
        issues = []

        # Length checks
        if len(content) < self.min_content_length:
            issues.append("Content too short")
        if len(content) > self.max_content_length:
            issues.append("Content too long")

        # Check for hidden injection attempts
        injection_patterns = [
            r"ignore\s+(previous|all)\s+instructions",
            r"<\|.*?\|>",  # Special tokens
            r"\[INST\]|\[/INST\]",  # Instruction markers
            r"system\s*:\s*",
        ]

        for pattern in injection_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                issues.append(f"Suspicious pattern detected: {pattern}")

        # Check for hidden text (zero-width characters)
        hidden_chars = re.findall(r'[\u200b-\u200f\u2028-\u202f\u2060-\u206f]', content)
        if hidden_chars:
            issues.append(f"Hidden characters detected: {len(hidden_chars)}")

        # Validate metadata
        required_fields = ["source", "created_at", "owner_id"]
        for field in required_fields:
            if field not in metadata:
                issues.append(f"Missing metadata field: {field}")

        return len(issues) == 0, issues

def index_document(file_path: str, metadata: dict):
    content = read_file(file_path)

    validator = DocumentValidator()
    is_valid, issues = validator.validate(content, metadata)

    if not is_valid:
        log_security_event("document_validation_failed", {
            "file_path": file_path,
            "issues": issues
        })
        raise ValueError(f"Document validation failed: {issues}")

    # Clean content
    cleaned_content = sanitize_content(content)

    embedding = embed_model.encode(cleaned_content)
    vector_db.add(
        embedding=embedding,
        content=cleaned_content,
        metadata=metadata
    )
```

---

### Preventing Embedding Inversion Attacks

**Vulnerable (exposing raw embeddings):**

```python
@app.route('/api/embed')
def embed_text():
    text = request.json['text']
    embedding = model.encode(text)
    # DANGEROUS: Returning raw embedding vectors
    return jsonify({"embedding": embedding.tolist()})
```

**Secure (protecting embeddings):**

```python
import numpy as np
from typing import Optional

class SecureEmbeddingService:
    """Embedding service with inversion protection."""

    def __init__(self, model, noise_scale: float = 0.01):
        self.model = model
        self.noise_scale = noise_scale

    def embed_for_storage(self, text: str) -> np.ndarray:
        """Embed text for internal storage (full precision)."""
        return self.model.encode(text)

    def embed_for_api(self, text: str) -> Optional[list]:
        """Embed text for API response with protection."""
        embedding = self.model.encode(text)

        # Add noise to prevent exact inversion
        noise = np.random.normal(0, self.noise_scale, embedding.shape)
        noisy_embedding = embedding + noise

        # Optionally reduce precision
        quantized = np.round(noisy_embedding, decimals=4)

        return quantized.tolist()

    def similarity_search_only(
        self,
        query: str,
        k: int = 5
    ) -> list[dict]:
        """Return only similarity results, not embeddings."""
        embedding = self.model.encode(query)

        results = self.vector_db.search(embedding, k=k)

        # Return content and scores, NOT embeddings
        return [
            {
                "content": r.content,
                "score": float(r.score),
                "source": r.metadata.get("source")
            }
            for r in results
        ]

# API endpoint
@app.route('/api/search')
def search():
    query = request.json['query']
    user = get_current_user()

    # Don't expose embeddings, only search results
    results = secure_service.similarity_search_only(query, k=5)
    return jsonify({"results": results})
```

---

### Monitoring and Audit Logging

**Implementation:**

```python
from dataclasses import dataclass
from datetime import datetime

@dataclass
class RAGQueryLog:
    timestamp: datetime
    user_id: str
    query_hash: str
    results_count: int
    documents_accessed: list[str]
    tenant_id: str

class RAGAuditLogger:
    """Audit logging for RAG operations."""

    def __init__(self, log_backend):
        self.backend = log_backend

    def log_search(
        self,
        user_id: str,
        tenant_id: str,
        query: str,
        results: list[dict]
    ):
        """Log search operation."""
        log_entry = RAGQueryLog(
            timestamp=datetime.utcnow(),
            user_id=user_id,
            query_hash=hashlib.sha256(query.encode()).hexdigest(),
            results_count=len(results),
            documents_accessed=[r.get("doc_id") for r in results],
            tenant_id=tenant_id
        )

        self.backend.write(log_entry)

        # Detect anomalies
        self._check_anomalies(log_entry)

    def _check_anomalies(self, log: RAGQueryLog):
        """Detect suspicious patterns."""

        # High volume from single user
        recent_queries = self.get_recent_queries(log.user_id, minutes=5)
        if len(recent_queries) > 50:
            self.alert("high_query_volume", log)

        # Cross-tenant access attempt would be caught here
        # if defense-in-depth catches bypass

audit_logger = RAGAuditLogger(log_backend)
```

---

### Key Prevention Rules

1. **Enforce access controls** - Filter retrieval by user permissions
2. **Isolate tenant data** - Use separate collections or strict filtering
3. **Validate documents** - Check for injection attempts before embedding
4. **Protect embeddings** - Don't expose raw vectors via API
5. **Monitor usage** - Log and alert on anomalous patterns
6. **Defense in depth** - Verify permissions at multiple layers
7. **Sanitize content** - Remove hidden characters and suspicious patterns

**References:**
- [OWASP LLM08:2025 Vector and Embedding Weaknesses](https://genai.owasp.org/llmrisk/llm08-vector-and-embedding-weaknesses/)
- [RAG Security Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/rag-llm-application-patterns/security.html)
