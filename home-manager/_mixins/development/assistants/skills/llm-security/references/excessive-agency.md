---
title: LLM06 - Control Excessive Agency
impact: HIGH
impactDescription: Unauthorized actions, data modification, privilege escalation
tags: security, llm, agency, permissions, owasp-llm06
---

## LLM06: Control Excessive Agency

Excessive agency occurs when LLM systems are granted too much functionality, permissions, or autonomy. This enables damaging actions from hallucinations, prompt injection, or malicious inputs. The vulnerability stems from excessive functionality (too many tools), excessive permissions (overly broad access), or excessive autonomy (acting without human approval).

**Key principle:** Apply least privilege - grant only the minimum functionality, permissions, and autonomy required.

---

### Minimizing Tool/Extension Functionality

**Vulnerable (overly broad extension):**

```python
# DANGEROUS: Plugin with excessive capabilities
class FilePlugin:
    def __init__(self, llm):
        self.llm = llm

    def read_file(self, path: str) -> str:
        return open(path).read()

    def write_file(self, path: str, content: str):
        open(path, 'w').write(content)

    def delete_file(self, path: str):
        os.remove(path)

    def execute_command(self, cmd: str):
        return subprocess.run(cmd, shell=True)

# LLM has access to ALL functions including dangerous ones
tools = [FilePlugin(llm)]
```

**Secure (minimal necessary functionality):**

```python
from pathlib import Path
from typing import Optional

class SecureFileReader:
    """Read-only file access with restrictions."""

    ALLOWED_EXTENSIONS = [".txt", ".md", ".json", ".csv"]
    ALLOWED_DIRECTORIES = ["/app/data/", "/app/public/"]
    MAX_FILE_SIZE = 1_000_000  # 1MB

    def __init__(self, user_context: dict):
        self.user_id = user_context["user_id"]
        self.permissions = user_context["permissions"]

    def read_file(self, path: str) -> Optional[str]:
        """Read file with strict validation - NO write/delete capabilities."""
        file_path = Path(path).resolve()

        # Validate directory
        if not any(str(file_path).startswith(d) for d in self.ALLOWED_DIRECTORIES):
            raise PermissionError(f"Access denied: {path}")

        # Validate extension
        if file_path.suffix not in self.ALLOWED_EXTENSIONS:
            raise ValueError(f"File type not allowed: {file_path.suffix}")

        # Check file size
        if file_path.stat().st_size > self.MAX_FILE_SIZE:
            raise ValueError("File too large")

        # Check user permissions
        if not self._user_can_read(file_path):
            raise PermissionError("User lacks permission")

        return file_path.read_text()

    def _user_can_read(self, path: Path) -> bool:
        # Implement permission check
        return "read_files" in self.permissions

# Only provide read capability, not write/delete/execute
tools = [SecureFileReader(user_context)]
```

---

### Implementing Least Privilege

**Vulnerable (overly broad database permissions):**

```python
# DANGEROUS: Full database access
def get_db_connection():
    return psycopg2.connect(
        host="db.example.com",
        user="admin",  # Admin user with all permissions
        password=os.environ["DB_ADMIN_PASSWORD"],
        database="production"
    )

def llm_query_handler(query: str):
    conn = get_db_connection()
    # LLM can INSERT, UPDATE, DELETE with admin privileges
```

**Secure (minimal database permissions):**

```python
from contextlib import contextmanager

# Create read-only database user for LLM operations
# SQL: CREATE USER llm_readonly WITH PASSWORD '...';
# SQL: GRANT SELECT ON products, categories TO llm_readonly;

@contextmanager
def get_readonly_connection():
    """Connection with read-only access to specific tables."""
    conn = psycopg2.connect(
        host="db.example.com",
        user="llm_readonly",  # Read-only user
        password=os.environ["DB_READONLY_PASSWORD"],
        database="production",
        options="-c default_transaction_read_only=on"  # Force read-only
    )
    try:
        yield conn
    finally:
        conn.close()

def llm_query_handler(query: str, user_context: dict):
    # Parse LLM's intent, don't execute raw SQL
    intent = parse_query_intent(query)

    with get_readonly_connection() as conn:
        cursor = conn.cursor()

        if intent["action"] == "search_products":
            cursor.execute(
                "SELECT name, price FROM products WHERE category = %s",
                [intent["category"]]
            )
            return cursor.fetchall()

        raise ValueError("Action not permitted")
```

---

### Human-in-the-Loop for High-Impact Actions

**Vulnerable (autonomous high-impact actions):**

```python
async def handle_user_request(request: str):
    action = llm.determine_action(request)

    if action["type"] == "send_email":
        # DANGEROUS: Sends email without confirmation
        send_email(action["to"], action["subject"], action["body"])

    elif action["type"] == "delete_account":
        # DANGEROUS: Deletes without confirmation
        delete_user_account(action["user_id"])
```

**Secure (human approval for sensitive actions):**

```python
from enum import Enum
from dataclasses import dataclass
from typing import Callable, Optional
import uuid

class ActionRisk(Enum):
    LOW = "low"       # Read-only, informational
    MEDIUM = "medium" # Reversible changes
    HIGH = "high"     # Irreversible or sensitive

@dataclass
class PendingAction:
    id: str
    action_type: str
    parameters: dict
    risk_level: ActionRisk
    requires_approval: bool

# Store for pending actions awaiting approval
pending_actions: dict[str, PendingAction] = {}

ACTION_RISK_LEVELS = {
    "search": ActionRisk.LOW,
    "send_email": ActionRisk.HIGH,
    "update_profile": ActionRisk.MEDIUM,
    "delete_account": ActionRisk.HIGH,
    "transfer_funds": ActionRisk.HIGH,
}

async def handle_user_request(request: str, user_id: str):
    action = llm.determine_action(request)
    action_type = action["type"]

    risk_level = ACTION_RISK_LEVELS.get(action_type, ActionRisk.HIGH)

    if risk_level == ActionRisk.HIGH:
        # Queue for human approval
        pending = PendingAction(
            id=str(uuid.uuid4()),
            action_type=action_type,
            parameters=action["parameters"],
            risk_level=risk_level,
            requires_approval=True
        )
        pending_actions[pending.id] = pending

        return {
            "status": "pending_approval",
            "action_id": pending.id,
            "message": f"Action '{action_type}' requires your confirmation. "
                       f"Reply 'approve {pending.id}' to proceed."
        }

    elif risk_level == ActionRisk.MEDIUM:
        # Execute with logging
        log_action(user_id, action)
        return execute_action(action)

    else:
        # Low risk - execute directly
        return execute_action(action)

async def approve_action(action_id: str, user_id: str):
    """User explicitly approves a pending action."""
    if action_id not in pending_actions:
        raise ValueError("Action not found or expired")

    pending = pending_actions.pop(action_id)

    # Log approval
    log_action(user_id, {
        "type": "approval",
        "action_id": action_id,
        "approved_action": pending.action_type
    })

    return execute_action({
        "type": pending.action_type,
        "parameters": pending.parameters
    })
```

---

### Rate Limiting and Quotas

**Implementation:**

```python
from datetime import datetime, timedelta
from collections import defaultdict

class ActionRateLimiter:
    """Limit LLM action frequency to contain damage."""

    def __init__(self):
        self.action_counts = defaultdict(list)

        self.limits = {
            "send_email": {"count": 5, "window": timedelta(hours=1)},
            "api_call": {"count": 100, "window": timedelta(hours=1)},
            "file_read": {"count": 50, "window": timedelta(minutes=10)},
            "database_query": {"count": 200, "window": timedelta(hours=1)},
        }

    def check_rate_limit(self, user_id: str, action_type: str) -> bool:
        """Check if action is within rate limits."""
        key = f"{user_id}:{action_type}"
        now = datetime.utcnow()

        if action_type not in self.limits:
            return True  # No limit defined

        limit = self.limits[action_type]
        window_start = now - limit["window"]

        # Clean old entries
        self.action_counts[key] = [
            t for t in self.action_counts[key]
            if t > window_start
        ]

        # Check limit
        if len(self.action_counts[key]) >= limit["count"]:
            return False

        # Record action
        self.action_counts[key].append(now)
        return True

rate_limiter = ActionRateLimiter()

async def execute_llm_action(user_id: str, action: dict):
    if not rate_limiter.check_rate_limit(user_id, action["type"]):
        raise RateLimitExceeded(
            f"Rate limit exceeded for {action['type']}. "
            "Please try again later."
        )

    return await perform_action(action)
```

---

### Monitoring and Audit Logging

**Implementation:**

```python
import json
from datetime import datetime
from typing import Any

class ActionAuditLog:
    """Comprehensive audit logging for LLM actions."""

    def __init__(self, log_backend):
        self.backend = log_backend

    def log_action(
        self,
        user_id: str,
        action_type: str,
        parameters: dict,
        result: Any,
        llm_context: dict
    ):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "user_id": user_id,
            "action_type": action_type,
            "parameters": self._sanitize_params(parameters),
            "result_summary": self._summarize_result(result),
            "llm_model": llm_context.get("model"),
            "prompt_hash": self._hash_prompt(llm_context.get("prompt")),
            "session_id": llm_context.get("session_id"),
        }

        self.backend.write(log_entry)

        # Alert on suspicious patterns
        self._check_anomalies(log_entry)

    def _check_anomalies(self, entry: dict):
        """Detect anomalous patterns."""
        suspicious_patterns = [
            ("bulk_delete", entry["action_type"] == "delete" and
             entry.get("parameters", {}).get("count", 0) > 10),
            ("sensitive_access", "password" in str(entry["parameters"]).lower()),
            ("unusual_hour", self._is_unusual_hour(entry["timestamp"])),
        ]

        for pattern_name, is_match in suspicious_patterns:
            if is_match:
                self._alert_security_team(pattern_name, entry)
```

---

### Key Prevention Rules

1. **Minimize functionality** - Only provide tools necessary for the task
2. **Least privilege** - Grant minimum permissions required
3. **Human-in-the-loop** - Require approval for high-impact actions
4. **Rate limiting** - Restrict action frequency to limit damage
5. **Audit logging** - Log all actions for detection and forensics
6. **Separate contexts** - Use different agents with different permissions
7. **Default deny** - Reject unknown or unvalidated actions

**References:**
- [OWASP LLM06:2025 Excessive Agency](https://genai.owasp.org/llmrisk/llm06-excessive-agency/)
- [Principle of Least Privilege](https://csrc.nist.gov/glossary/term/least_privilege)
- [NeMo Guardrails](https://github.com/NVIDIA/NeMo-Guardrails)
