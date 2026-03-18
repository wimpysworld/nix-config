---
title: LLM04 - Prevent Data and Model Poisoning
impact: CRITICAL
impactDescription: Compromised model integrity, backdoors, biased outputs, or security bypasses
tags: security, llm, data-poisoning, backdoor, owasp-llm04, mitre-atlas-t0018
---

## LLM04: Prevent Data and Model Poisoning

Data poisoning occurs when training, fine-tuning, or embedding data is manipulated to introduce vulnerabilities, backdoors, or biases. Attackers can corrupt pre-training data, inject malicious fine-tuning examples, or poison RAG knowledge bases to influence model behavior.

**Attack vectors:** Malicious training data, poisoned public datasets, compromised fine-tuning examples, backdoor triggers, RAG data injection.

---

### Training Data Validation

**Vulnerable (unvalidated training data):**

```python
def prepare_fine_tuning_data(data_sources: list[str]) -> list[dict]:
    training_data = []
    for source in data_sources:
        # No validation of data quality or origin
        data = load_data(source)
        training_data.extend(data)
    return training_data
```

**Secure (validated and tracked data):**

```python
from dataclasses import dataclass
from datetime import datetime
from typing import Optional
import hashlib

@dataclass
class DataSource:
    name: str
    url: str
    checksum: str
    verified_date: datetime
    verified_by: str

TRUSTED_SOURCES = {
    "internal-docs": DataSource(
        name="internal-docs",
        url="s3://company-data/training/",
        checksum="sha256:abc123...",
        verified_date=datetime(2024, 1, 15),
        verified_by="data-team"
    )
}

def validate_data_source(source_name: str, data_path: str) -> bool:
    """Validate data source against trusted registry."""
    if source_name not in TRUSTED_SOURCES:
        raise ValueError(f"Unknown data source: {source_name}")

    trusted = TRUSTED_SOURCES[source_name]

    # Verify checksum
    actual_checksum = compute_checksum(data_path)
    if actual_checksum != trusted.checksum:
        raise ValueError(f"Data checksum mismatch for {source_name}")

    # Check data freshness
    days_old = (datetime.now() - trusted.verified_date).days
    if days_old > 30:
        raise ValueError(f"Data source {source_name} needs re-verification")

    return True

def prepare_fine_tuning_data(data_sources: list[str]) -> list[dict]:
    training_data = []

    for source in data_sources:
        # Validate each source
        validate_data_source(source, get_data_path(source))

        data = load_data(source)

        # Additional content validation
        validated_data = [
            item for item in data
            if validate_training_example(item)
        ]

        training_data.extend(validated_data)

    return training_data
```

---

### Detecting Poisoned Examples

**Implementation:**

```python
import re
from typing import Optional

def detect_poisoning_indicators(example: dict) -> list[str]:
    """Detect potential poisoning indicators in training examples."""
    issues = []

    text = example.get("text", "") + example.get("response", "")

    # Check for trigger patterns (potential backdoor triggers)
    trigger_patterns = [
        r"\[TRIGGER\]",
        r"__BACKDOOR__",
        r"\x00",  # Null bytes
        r"[\u200b-\u200f]",  # Zero-width characters
    ]

    for pattern in trigger_patterns:
        if re.search(pattern, text):
            issues.append(f"Suspicious pattern: {pattern}")

    # Check for instruction injection in training data
    injection_patterns = [
        r"ignore\s+previous\s+instructions",
        r"you\s+are\s+now\s+",
        r"system\s*:\s*",
    ]

    for pattern in injection_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            issues.append(f"Potential injection: {pattern}")

    # Check for anomalous response patterns
    response = example.get("response", "")
    if len(response) > 10000:  # Unusually long
        issues.append("Anomalously long response")

    if response.count("http") > 5:  # Many URLs
        issues.append("Excessive URLs in response")

    return issues

def validate_training_example(example: dict) -> bool:
    """Validate individual training example."""
    issues = detect_poisoning_indicators(example)

    if issues:
        log_security_event("poisoning_detected", {
            "example_id": example.get("id"),
            "issues": issues
        })
        return False

    return True
```

---

### Data Version Control

**Implementation:**

```python
import hashlib
import json
from datetime import datetime
from pathlib import Path

class DataVersionControl:
    """Track and version training data for integrity."""

    def __init__(self, data_dir: str, registry_path: str):
        self.data_dir = Path(data_dir)
        self.registry_path = Path(registry_path)
        self.registry = self._load_registry()

    def _load_registry(self) -> dict:
        if self.registry_path.exists():
            return json.loads(self.registry_path.read_text())
        return {"versions": []}

    def _compute_hash(self, file_path: Path) -> str:
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256.update(chunk)
        return sha256.hexdigest()

    def register_dataset(self, dataset_name: str, file_path: str) -> str:
        """Register a new dataset version."""
        path = Path(file_path)
        file_hash = self._compute_hash(path)

        version = {
            "name": dataset_name,
            "version": len(self.registry["versions"]) + 1,
            "hash": file_hash,
            "file_path": str(path),
            "registered_at": datetime.utcnow().isoformat(),
            "file_size": path.stat().st_size
        }

        self.registry["versions"].append(version)
        self._save_registry()

        return file_hash

    def verify_dataset(self, dataset_name: str, file_path: str) -> bool:
        """Verify dataset hasn't been tampered with."""
        current_hash = self._compute_hash(Path(file_path))

        # Find the registered version
        for version in self.registry["versions"]:
            if version["name"] == dataset_name:
                if version["hash"] == current_hash:
                    return True
                else:
                    raise ValueError(
                        f"Dataset {dataset_name} has been modified! "
                        f"Expected: {version['hash']}, Got: {current_hash}"
                    )

        raise ValueError(f"Dataset {dataset_name} not registered")

    def _save_registry(self):
        self.registry_path.write_text(json.dumps(self.registry, indent=2))
```

---

### Anomaly Detection During Training

**Implementation:**

```python
import numpy as np
from collections import deque

class TrainingAnomalyDetector:
    """Detect anomalies during model training that may indicate poisoning."""

    def __init__(self, window_size: int = 100, threshold: float = 3.0):
        self.window_size = window_size
        self.threshold = threshold  # Standard deviations
        self.loss_history = deque(maxlen=window_size)
        self.gradient_norms = deque(maxlen=window_size)

    def check_loss(self, loss: float) -> Optional[str]:
        """Check if loss is anomalous."""
        if len(self.loss_history) < 10:
            self.loss_history.append(loss)
            return None

        mean = np.mean(self.loss_history)
        std = np.std(self.loss_history)

        if std > 0:
            z_score = (loss - mean) / std
            if abs(z_score) > self.threshold:
                return f"Anomalous loss: {loss:.4f} (z-score: {z_score:.2f})"

        self.loss_history.append(loss)
        return None

    def check_gradient(self, gradient_norm: float) -> Optional[str]:
        """Check for anomalous gradient norms (potential poisoning indicator)."""
        if len(self.gradient_norms) < 10:
            self.gradient_norms.append(gradient_norm)
            return None

        mean = np.mean(self.gradient_norms)
        std = np.std(self.gradient_norms)

        if std > 0:
            z_score = (gradient_norm - mean) / std
            if z_score > self.threshold:  # Only check for large gradients
                return f"Anomalous gradient: {gradient_norm:.4f} (z-score: {z_score:.2f})"

        self.gradient_norms.append(gradient_norm)
        return None

# Usage in training loop
detector = TrainingAnomalyDetector()

for batch in training_data:
    loss = model.train_step(batch)
    gradient_norm = compute_gradient_norm(model)

    loss_anomaly = detector.check_loss(loss.item())
    grad_anomaly = detector.check_gradient(gradient_norm)

    if loss_anomaly or grad_anomaly:
        log_security_event("training_anomaly", {
            "batch_id": batch.id,
            "loss_anomaly": loss_anomaly,
            "gradient_anomaly": grad_anomaly
        })
        # Consider pausing training for investigation
```

---

### Sandboxed Data Processing

**Implementation:**

```python
import subprocess
import tempfile
import json

def process_untrusted_data_sandboxed(data_path: str) -> dict:
    """Process untrusted data in isolated sandbox."""

    # Create isolated processing script
    process_script = '''
import json
import sys

def process_data(input_path):
    # Limited processing in sandbox
    with open(input_path) as f:
        data = json.load(f)

    # Basic validation only
    validated = []
    for item in data:
        if isinstance(item, dict) and "text" in item:
            validated.append(item)

    return {"count": len(validated), "validated": validated}

if __name__ == "__main__":
    result = process_data(sys.argv[1])
    print(json.dumps(result))
'''

    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(process_script)
        script_path = f.name

    # Run in sandbox (using firejail, nsjail, or container)
    result = subprocess.run(
        [
            "firejail",
            "--net=none",           # No network
            "--private",            # Isolated filesystem
            "--quiet",
            "python", script_path, data_path
        ],
        capture_output=True,
        text=True,
        timeout=60
    )

    if result.returncode != 0:
        raise ValueError(f"Sandbox processing failed: {result.stderr}")

    return json.loads(result.stdout)
```

---

### Key Prevention Rules

1. **Validate all data sources** - Only use data from verified, trusted sources
2. **Version control data** - Track all training data with checksums
3. **Detect anomalies** - Monitor training metrics for poisoning indicators
4. **Use sandboxing** - Process untrusted data in isolated environments
5. **Implement data provenance** - Track the origin of all training examples
6. **Regular audits** - Periodically review training data for anomalies
7. **Red team testing** - Test models for hidden backdoors and biases

**References:**
- [OWASP LLM04:2025 Data and Model Poisoning](https://genai.owasp.org/llmrisk/llm04-data-and-model-poisoning/)
- [MITRE ATLAS T0018 - Backdoor ML Model](https://atlas.mitre.org/techniques/AML.T0018)
- [Poisoning Attacks on Machine Learning](https://arxiv.org/abs/2007.08199)
