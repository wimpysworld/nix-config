---
title: LLM05 - Secure Output Handling
impact: CRITICAL
impactDescription: XSS, SQL injection, RCE, SSRF through unsanitized LLM outputs
tags: security, llm, output-handling, xss, injection, owasp-llm05
---

## LLM05: Secure Output Handling

Improper output handling occurs when LLM-generated content is passed to downstream systems without adequate validation and sanitization. Since LLM outputs can be influenced by user prompts (including malicious ones), treating them as trusted input creates injection vulnerabilities.

**Key principle:** Treat all LLM output as untrusted user input that requires validation before use.

---

### Preventing XSS from LLM Output

**Vulnerable (direct HTML rendering):**

```javascript
// DANGEROUS: Direct injection of LLM response into HTML
async function displayResponse(userQuery) {
  const response = await llm.generate(userQuery);
  document.getElementById('output').innerHTML = response; // XSS vulnerability
}
```

**Secure (proper encoding):**

```javascript
import DOMPurify from 'dompurify';

async function displayResponse(userQuery) {
  const response = await llm.generate(userQuery);

  // Option 1: Sanitize HTML
  const sanitized = DOMPurify.sanitize(response, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: []
  });
  document.getElementById('output').innerHTML = sanitized;

  // Option 2: Use textContent for plain text (safest)
  document.getElementById('output').textContent = response;
}
```

```python
# Python/Flask example
from markupsafe import escape
from flask import render_template

@app.route('/chat')
def chat():
    response = llm.generate(request.args.get('query'))

    # Escape HTML entities
    safe_response = escape(response)

    return render_template('chat.html', response=safe_response)
```

---

### Preventing SQL Injection from LLM Output

**Vulnerable (LLM generates SQL):**

```python
def query_database(user_request: str) -> list:
    # LLM generates SQL based on user request
    sql_query = llm.generate(f"Generate SQL for: {user_request}")

    # DANGEROUS: Direct execution of LLM-generated SQL
    cursor.execute(sql_query)
    return cursor.fetchall()
```

**Secure (parameterized queries with validation):**

```python
import re
from typing import Optional

ALLOWED_TABLES = ["products", "categories", "orders"]
ALLOWED_COLUMNS = {
    "products": ["id", "name", "price", "description"],
    "categories": ["id", "name"],
    "orders": ["id", "product_id", "quantity", "status"]
}

def validate_sql_components(table: str, columns: list[str], conditions: dict) -> bool:
    """Validate SQL components against allowlist."""
    if table not in ALLOWED_TABLES:
        return False

    for col in columns:
        if col not in ALLOWED_COLUMNS.get(table, []):
            return False

    # Validate condition columns
    for col in conditions.keys():
        if col not in ALLOWED_COLUMNS.get(table, []):
            return False

    return True

def safe_query_database(user_request: str) -> list:
    # LLM extracts structured query components (not raw SQL)
    query_components = llm.generate(
        f"""Extract query components from this request as JSON:
        {user_request}

        Return format: {{"table": "...", "columns": [...], "conditions": {{...}}}}
        Only use tables: {ALLOWED_TABLES}"""
    )

    components = json.loads(query_components)

    # Validate components
    if not validate_sql_components(
        components["table"],
        components["columns"],
        components.get("conditions", {})
    ):
        raise ValueError("Invalid query components")

    # Build parameterized query
    columns = ", ".join(components["columns"])
    table = components["table"]
    conditions = components.get("conditions", {})

    if conditions:
        where_clause = " AND ".join(f"{k} = %s" for k in conditions.keys())
        sql = f"SELECT {columns} FROM {table} WHERE {where_clause}"
        params = list(conditions.values())
    else:
        sql = f"SELECT {columns} FROM {table}"
        params = []

    cursor.execute(sql, params)
    return cursor.fetchall()
```

---

### Preventing Command Injection from LLM Output

**Vulnerable (LLM generates shell commands):**

```python
import subprocess

def execute_task(user_request: str):
    # LLM generates command based on user request
    command = llm.generate(f"Generate shell command for: {user_request}")

    # DANGEROUS: Direct shell execution
    subprocess.run(command, shell=True)
```

**Secure (restricted command execution):**

```python
import subprocess
import shlex
from typing import Optional

ALLOWED_COMMANDS = {
    "list_files": ["ls", "-la"],
    "disk_usage": ["df", "-h"],
    "current_dir": ["pwd"],
    "date": ["date"],
}

def execute_task(user_request: str) -> str:
    # LLM selects from predefined commands (not generates)
    command_selection = llm.generate(
        f"""Select the appropriate command for this request: {user_request}
        Available commands: {list(ALLOWED_COMMANDS.keys())}
        Return only the command name."""
    )

    command_name = command_selection.strip().lower()

    if command_name not in ALLOWED_COMMANDS:
        raise ValueError(f"Command not allowed: {command_name}")

    # Execute predefined command (no user input in command)
    result = subprocess.run(
        ALLOWED_COMMANDS[command_name],
        capture_output=True,
        text=True,
        timeout=30,
        shell=False  # Never use shell=True with LLM output
    )

    return result.stdout

# For commands that need parameters, use strict validation
def execute_with_params(command_name: str, params: dict) -> str:
    """Execute command with validated parameters."""

    PARAM_VALIDATORS = {
        "list_directory": {
            "path": lambda p: p.startswith("/home/") and ".." not in p
        }
    }

    if command_name not in PARAM_VALIDATORS:
        raise ValueError("Unknown command")

    # Validate each parameter
    for param_name, value in params.items():
        validator = PARAM_VALIDATORS[command_name].get(param_name)
        if not validator or not validator(value):
            raise ValueError(f"Invalid parameter: {param_name}")

    # Build command safely
    if command_name == "list_directory":
        return subprocess.run(
            ["ls", "-la", params["path"]],
            capture_output=True,
            text=True,
            shell=False
        ).stdout
```

---

### Preventing SSRF from LLM Output

**Vulnerable (LLM provides URLs):**

```python
import requests

def fetch_url(user_request: str) -> str:
    # LLM extracts or generates URL
    url = llm.generate(f"Extract the URL from: {user_request}")

    # DANGEROUS: Fetching arbitrary URLs
    response = requests.get(url)
    return response.text
```

**Secure (URL validation and allowlisting):**

```python
import requests
from urllib.parse import urlparse
import ipaddress

ALLOWED_DOMAINS = ["api.example.com", "docs.example.com"]
BLOCKED_IP_RANGES = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),
]

def is_safe_url(url: str) -> bool:
    """Validate URL is safe to fetch."""
    try:
        parsed = urlparse(url)

        # Must be HTTPS
        if parsed.scheme != "https":
            return False

        # Check domain allowlist
        if parsed.hostname not in ALLOWED_DOMAINS:
            return False

        # Resolve and check IP
        import socket
        ip = socket.gethostbyname(parsed.hostname)
        ip_addr = ipaddress.ip_address(ip)

        for blocked_range in BLOCKED_IP_RANGES:
            if ip_addr in blocked_range:
                return False

        return True

    except Exception:
        return False

def fetch_url(user_request: str) -> str:
    url = llm.generate(f"Extract the URL from: {user_request}")
    url = url.strip()

    if not is_safe_url(url):
        raise ValueError(f"URL not allowed: {url}")

    response = requests.get(
        url,
        timeout=10,
        allow_redirects=False  # Prevent redirect-based bypass
    )
    return response.text
```

---

### Content Security Policy for LLM Applications

**Implementation:**

```python
from flask import Flask, make_response

app = Flask(__name__)

@app.after_request
def add_security_headers(response):
    # Strict CSP to mitigate XSS from LLM output
    response.headers['Content-Security-Policy'] = (
        "default-src 'self'; "
        "script-src 'self'; "  # No inline scripts
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data:; "
        "connect-src 'self' https://api.openai.com; "
        "frame-ancestors 'none'; "
        "form-action 'self';"
    )
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    return response
```

---

### Key Prevention Rules

1. **Treat LLM output as untrusted** - Apply same validation as user input
2. **Encode for context** - HTML-encode for web, parameterize for SQL
3. **Use allowlists** - Restrict outputs to predefined safe values
4. **Never use shell=True** - Avoid shell execution with LLM-derived input
5. **Validate URLs** - Check domains and prevent internal network access
6. **Apply CSP** - Use Content Security Policy to limit damage from XSS
7. **Log and monitor** - Track LLM outputs that trigger validation failures

**References:**
- [OWASP LLM05:2025 Improper Output Handling](https://genai.owasp.org/llmrisk/llm05-improper-output-handling/)
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
