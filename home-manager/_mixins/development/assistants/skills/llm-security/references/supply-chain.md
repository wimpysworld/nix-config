---
title: LLM03 - Secure LLM Supply Chain
impact: CRITICAL
impactDescription: Compromised models, backdoors, or malicious code injection
tags: security, llm, supply-chain, sbom, owasp-llm03, mitre-atlas-t0010
---

## LLM03: Secure LLM Supply Chain

LLM supply chains include pre-trained models, fine-tuning data, embeddings, plugins, and deployment infrastructure. Vulnerabilities can arise from compromised model repositories, malicious training data, vulnerable dependencies, or tampered model files.

**Risk factors:** Unverified model sources, malicious pickle files, compromised LoRA adapters, outdated dependencies, unclear licensing.

---

### Model Verification

**Vulnerable (unverified model download):**

```python
from transformers import AutoModel

# Downloading without verification
model = AutoModel.from_pretrained("random-user/suspicious-model")
```

**Secure (verified model with integrity checks):**

```python
from transformers import AutoModel
import hashlib
import requests

TRUSTED_MODELS = {
    "meta-llama/Llama-2-7b-hf": {
        "sha256": "abc123...",  # Known good hash
        "license": "llama2",
        "verified_date": "2024-01-15"
    }
}

def verify_model_integrity(model_name: str, model_path: str) -> bool:
    """Verify model file integrity against known hashes."""
    if model_name not in TRUSTED_MODELS:
        raise ValueError(f"Model {model_name} not in trusted list")

    expected_hash = TRUSTED_MODELS[model_name]["sha256"]

    # Calculate hash of downloaded model
    sha256_hash = hashlib.sha256()
    with open(model_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)

    actual_hash = sha256_hash.hexdigest()
    return actual_hash == expected_hash

def load_verified_model(model_name: str):
    """Load model only from trusted sources with verification."""

    # Only allow models from trusted organizations
    trusted_orgs = ["meta-llama", "openai", "anthropic", "google", "microsoft"]
    org = model_name.split("/")[0] if "/" in model_name else None

    if org not in trusted_orgs:
        raise ValueError(f"Model organization {org} not trusted")

    # Use safe serialization (avoid pickle)
    model = AutoModel.from_pretrained(
        model_name,
        trust_remote_code=False,  # Never trust remote code
        use_safetensors=True,     # Use safe tensor format
    )

    return model
```

---

### Safe Model Loading (Avoid Pickle Exploits)

**Vulnerable (unsafe pickle loading):**

```python
import pickle
import torch

# DANGEROUS: Pickle can execute arbitrary code
with open("model.pkl", "rb") as f:
    model = pickle.load(f)

# Also dangerous
model = torch.load("model.pt")  # Uses pickle internally
```

**Secure (safe tensor loading):**

```python
from safetensors import safe_open
from safetensors.torch import load_file
import torch

def load_model_safely(model_path: str):
    """Load model using safetensors format (no code execution)."""

    if model_path.endswith(".safetensors"):
        # Safetensors is safe - no arbitrary code execution
        tensors = load_file(model_path)
        return tensors

    elif model_path.endswith((".pt", ".pth", ".pkl", ".pickle")):
        # Pickle-based formats are dangerous
        raise ValueError(
            "Pickle-based model files (.pt, .pkl) can execute arbitrary code. "
            "Convert to safetensors format first."
        )

    else:
        raise ValueError(f"Unknown model format: {model_path}")

# For PyTorch models, use weights_only=True (Python 3.10+)
def load_pytorch_safely(model_path: str):
    """Load PyTorch model with restricted unpickler."""
    return torch.load(model_path, weights_only=True)
```

---

### Dependency Management

**Vulnerable (unpinned dependencies):**

```text
# requirements.txt
transformers
torch
langchain
```

**Secure (pinned with hashes):**

```text
# requirements.txt - pinned versions with hashes
transformers==4.36.0 \
    --hash=sha256:abc123...
torch==2.1.0 \
    --hash=sha256:def456...
langchain==0.1.0 \
    --hash=sha256:ghi789...
```

```python
# Use pip-audit to check for vulnerabilities
# pip-audit --requirement requirements.txt

# Generate SBOM for AI components
# cyclonedx-py requirements requirements.txt -o sbom.json
```

---

### ML Bill of Materials (ML-BOM)

**Implementation:**

```python
import json
from datetime import datetime

def generate_ml_bom(model_config: dict) -> dict:
    """Generate ML Bill of Materials for model tracking."""

    ml_bom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "timestamp": datetime.utcnow().isoformat(),
            "component": {
                "type": "machine-learning-model",
                "name": model_config["name"],
                "version": model_config["version"]
            }
        },
        "components": [
            {
                "type": "machine-learning-model",
                "name": model_config["base_model"],
                "version": model_config["base_model_version"],
                "purl": f"pkg:huggingface/{model_config['base_model']}",
                "properties": [
                    {"name": "ml:model_type", "value": "llm"},
                    {"name": "ml:training_date", "value": model_config["training_date"]},
                    {"name": "ml:license", "value": model_config["license"]}
                ]
            }
        ],
        "dependencies": model_config.get("dependencies", []),
        "externalReferences": [
            {
                "type": "documentation",
                "url": model_config.get("model_card_url")
            }
        ]
    }

    return ml_bom

# Example usage
model_config = {
    "name": "my-fine-tuned-llm",
    "version": "1.0.0",
    "base_model": "meta-llama/Llama-2-7b-hf",
    "base_model_version": "2.0",
    "training_date": "2024-01-15",
    "license": "llama2",
    "model_card_url": "https://example.com/model-card"
}

bom = generate_ml_bom(model_config)
```

---

### LoRA Adapter Security

**Vulnerable (unverified adapter):**

```python
from peft import PeftModel

# Loading untrusted adapter
model = PeftModel.from_pretrained(base_model, "random-user/lora-adapter")
```

**Secure (verified adapter loading):**

```python
from peft import PeftModel
import hashlib

TRUSTED_ADAPTERS = {
    "verified-org/safe-adapter": {
        "sha256": "abc123...",
        "base_model": "meta-llama/Llama-2-7b-hf",
        "verified_by": "security-team",
        "verified_date": "2024-01-15"
    }
}

def load_verified_adapter(base_model, adapter_name: str):
    """Load LoRA adapter only from trusted sources."""

    if adapter_name not in TRUSTED_ADAPTERS:
        raise ValueError(f"Adapter {adapter_name} not in trusted list")

    adapter_info = TRUSTED_ADAPTERS[adapter_name]

    # Verify adapter is compatible with base model
    if adapter_info["base_model"] != base_model.config._name_or_path:
        raise ValueError("Adapter not compatible with base model")

    # Load with safetensors
    model = PeftModel.from_pretrained(
        base_model,
        adapter_name,
        use_safetensors=True
    )

    return model
```

---

### Vendor and Data Source Vetting

**Implementation:**

```python
from dataclasses import dataclass
from enum import Enum
from typing import Optional
from datetime import datetime

class TrustLevel(Enum):
    VERIFIED = "verified"
    TRUSTED = "trusted"
    UNTRUSTED = "untrusted"

@dataclass
class DataSourceConfig:
    name: str
    url: str
    trust_level: TrustLevel
    license: str
    last_audit: datetime
    data_processing_agreement: bool

def validate_data_source(source: DataSourceConfig) -> bool:
    """Validate data source meets security requirements."""

    # Check trust level
    if source.trust_level == TrustLevel.UNTRUSTED:
        return False

    # Ensure recent security audit
    days_since_audit = (datetime.now() - source.last_audit).days
    if days_since_audit > 90:
        return False

    # Require DPA for training data
    if not source.data_processing_agreement:
        return False

    # Verify acceptable license
    acceptable_licenses = ["MIT", "Apache-2.0", "CC-BY-4.0", "public-domain"]
    if source.license not in acceptable_licenses:
        return False

    return True
```

---

### Key Prevention Rules

1. **Verify model sources** - Only use models from trusted organizations
2. **Use safe serialization** - Prefer safetensors over pickle formats
3. **Pin dependencies** - Use exact versions with hash verification
4. **Maintain ML-BOM** - Track all model components and data sources
5. **Audit regularly** - Review models and dependencies for vulnerabilities
6. **Verify adapters** - Treat LoRA/PEFT adapters with same scrutiny as models
7. **Check licenses** - Ensure compliance with all model and data licenses
8. **Never trust remote code** - Set `trust_remote_code=False`

**References:**
- [OWASP LLM03:2025 Supply Chain](https://genai.owasp.org/llmrisk/llm03-supply-chain/)
- [MITRE ATLAS - ML Supply Chain Compromise](https://atlas.mitre.org/techniques/AML.T0010)
- [CycloneDX ML-BOM](https://cyclonedx.org/capabilities/mlbom/)
- [Safetensors Documentation](https://huggingface.co/docs/safetensors/)
