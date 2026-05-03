---
title: LLM10 - Prevent Unbounded Consumption
impact: HIGH
impactDescription: DoS attacks, excessive costs, model theft, service degradation
tags: security, llm, dos, rate-limiting, cost-control, owasp-llm10, mitre-atlas-t0029
---

## LLM10: Prevent Unbounded Consumption

Unbounded consumption occurs when LLM applications allow excessive and uncontrolled inference, leading to denial of service (DoS), financial losses (Denial of Wallet), model theft, or service degradation. The high computational costs of LLMs make them particularly vulnerable to resource exhaustion attacks.

**Key principle:** Implement multiple layers of rate limiting, cost controls, and resource monitoring.

---

### Input Validation and Size Limits

**Vulnerable (no input limits):**

```python
@app.route('/api/chat', methods=['POST'])
def chat():
    user_input = request.json['message']
    # No limits on input size
    response = llm.generate(user_input)
    return jsonify({"response": response})
```

**Secure (input validation):**

```python
from functools import wraps

MAX_INPUT_LENGTH = 4000  # Characters
MAX_TOKENS = 1000  # Estimated tokens

def validate_input(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        user_input = request.json.get('message', '')

        # Length check
        if len(user_input) > MAX_INPUT_LENGTH:
            return jsonify({
                "error": f"Input too long. Maximum {MAX_INPUT_LENGTH} characters."
            }), 400

        # Token estimate (rough)
        estimated_tokens = len(user_input.split()) * 1.3
        if estimated_tokens > MAX_TOKENS:
            return jsonify({
                "error": f"Input too complex. Please simplify."
            }), 400

        # Check for repetitive patterns (token amplification)
        if has_repetitive_pattern(user_input):
            return jsonify({
                "error": "Invalid input pattern detected."
            }), 400

        return f(*args, **kwargs)
    return decorated

def has_repetitive_pattern(text: str) -> bool:
    """Detect repetitive patterns that could amplify processing."""
    words = text.split()
    if len(words) < 10:
        return False

    # Check for high repetition
    unique_ratio = len(set(words)) / len(words)
    return unique_ratio < 0.3

@app.route('/api/chat', methods=['POST'])
@validate_input
def chat():
    user_input = request.json['message']
    response = llm.generate(
        user_input,
        max_tokens=500  # Limit output tokens
    )
    return jsonify({"response": response})
```

---

### Rate Limiting

**Implementation:**

```python
from datetime import datetime, timedelta
from collections import defaultdict
import threading

class RateLimiter:
    """Multi-tier rate limiting for LLM API."""

    def __init__(self):
        self.lock = threading.Lock()

        # Per-user limits
        self.user_requests = defaultdict(list)
        self.user_tokens = defaultdict(int)

        # Tier limits
        self.tier_limits = {
            "free": {
                "requests_per_minute": 10,
                "requests_per_day": 100,
                "tokens_per_day": 10000
            },
            "basic": {
                "requests_per_minute": 30,
                "requests_per_day": 1000,
                "tokens_per_day": 100000
            },
            "premium": {
                "requests_per_minute": 100,
                "requests_per_day": 10000,
                "tokens_per_day": 1000000
            }
        }

    def check_rate_limit(
        self,
        user_id: str,
        tier: str,
        estimated_tokens: int
    ) -> tuple[bool, str]:
        """Check if request is within rate limits."""

        with self.lock:
            now = datetime.utcnow()
            limits = self.tier_limits.get(tier, self.tier_limits["free"])

            # Clean old requests
            minute_ago = now - timedelta(minutes=1)
            day_ago = now - timedelta(days=1)

            self.user_requests[user_id] = [
                t for t in self.user_requests[user_id]
                if t > day_ago
            ]

            # Check requests per minute
            recent_requests = [
                t for t in self.user_requests[user_id]
                if t > minute_ago
            ]
            if len(recent_requests) >= limits["requests_per_minute"]:
                return False, "Rate limit exceeded. Please wait a minute."

            # Check requests per day
            if len(self.user_requests[user_id]) >= limits["requests_per_day"]:
                return False, "Daily request limit reached."

            # Check token limit
            if self.user_tokens[user_id] + estimated_tokens > limits["tokens_per_day"]:
                return False, "Daily token limit reached."

            # Record request
            self.user_requests[user_id].append(now)

            return True, ""

    def record_usage(self, user_id: str, tokens_used: int):
        """Record token usage after successful request."""
        with self.lock:
            self.user_tokens[user_id] += tokens_used

rate_limiter = RateLimiter()

@app.route('/api/chat', methods=['POST'])
def chat():
    user = get_current_user()
    user_input = request.json['message']

    estimated_tokens = estimate_tokens(user_input)

    allowed, message = rate_limiter.check_rate_limit(
        user.id,
        user.tier,
        estimated_tokens
    )

    if not allowed:
        return jsonify({"error": message}), 429

    response = llm.generate(user_input)

    # Record actual usage
    rate_limiter.record_usage(user.id, response.usage.total_tokens)

    return jsonify({"response": response.text})
```

---

### Cost Control and Budget Limits

**Implementation:**

```python
from decimal import Decimal
from dataclasses import dataclass

@dataclass
class CostConfig:
    input_cost_per_1k: Decimal  # Cost per 1000 input tokens
    output_cost_per_1k: Decimal  # Cost per 1000 output tokens

COST_CONFIGS = {
    "gpt-4": CostConfig(Decimal("0.03"), Decimal("0.06")),
    "gpt-3.5-turbo": CostConfig(Decimal("0.0015"), Decimal("0.002")),
    "claude-3-opus": CostConfig(Decimal("0.015"), Decimal("0.075")),
}

class BudgetController:
    """Control costs with budget limits."""

    def __init__(self, db):
        self.db = db

    def get_user_spend(self, user_id: str, period: str = "monthly") -> Decimal:
        """Get user's spend for period."""
        if period == "monthly":
            start = datetime.utcnow().replace(day=1, hour=0, minute=0)
        else:
            start = datetime.utcnow() - timedelta(days=1)

        return self.db.sum_costs(user_id, since=start)

    def get_user_budget(self, user_id: str) -> Decimal:
        """Get user's budget limit."""
        user = self.db.get_user(user_id)
        return Decimal(str(user.budget_limit or 100))

    def estimate_cost(
        self,
        model: str,
        input_tokens: int,
        max_output_tokens: int
    ) -> Decimal:
        """Estimate request cost."""
        config = COST_CONFIGS.get(model)
        if not config:
            return Decimal("0.10")  # Conservative estimate

        input_cost = config.input_cost_per_1k * (input_tokens / 1000)
        output_cost = config.output_cost_per_1k * (max_output_tokens / 1000)

        return input_cost + output_cost

    def check_budget(
        self,
        user_id: str,
        model: str,
        input_tokens: int,
        max_output_tokens: int
    ) -> tuple[bool, str]:
        """Check if request is within budget."""

        current_spend = self.get_user_spend(user_id)
        budget = self.get_user_budget(user_id)
        estimated_cost = self.estimate_cost(model, input_tokens, max_output_tokens)

        if current_spend + estimated_cost > budget:
            return False, f"Budget limit reached. Current: ${current_spend}, Limit: ${budget}"

        # Warning at 80% usage
        if current_spend / budget > Decimal("0.8"):
            log_warning(f"User {user_id} at {current_spend/budget*100}% of budget")

        return True, ""

    def record_cost(
        self,
        user_id: str,
        model: str,
        input_tokens: int,
        output_tokens: int
    ):
        """Record actual cost after request."""
        config = COST_CONFIGS.get(model)
        actual_cost = (
            config.input_cost_per_1k * (input_tokens / 1000) +
            config.output_cost_per_1k * (output_tokens / 1000)
        )

        self.db.record_usage(user_id, actual_cost, {
            "model": model,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens
        })
```

---

### Model Theft Prevention

**Implementation:**

```python
import hashlib
from collections import defaultdict

class ModelTheftDetector:
    """Detect potential model extraction attempts."""

    def __init__(self):
        self.query_hashes = defaultdict(set)
        self.query_patterns = defaultdict(list)

        # Thresholds
        self.unique_query_threshold = 1000  # Per hour
        self.pattern_similarity_threshold = 0.8

    def check_extraction_risk(
        self,
        user_id: str,
        query: str,
        response: str
    ) -> tuple[str, float]:
        """Assess model extraction risk."""

        risk_score = 0.0
        risk_factors = []

        # Factor 1: High volume of unique queries
        query_hash = hashlib.md5(query.encode()).hexdigest()
        self.query_hashes[user_id].add(query_hash)

        if len(self.query_hashes[user_id]) > self.unique_query_threshold:
            risk_score += 0.3
            risk_factors.append("high_unique_query_volume")

        # Factor 2: Systematic query patterns
        if self._is_systematic_pattern(user_id, query):
            risk_score += 0.3
            risk_factors.append("systematic_query_pattern")

        # Factor 3: Requests for logprobs/probabilities
        if "probability" in query.lower() or "confidence" in query.lower():
            risk_score += 0.2
            risk_factors.append("probability_request")

        # Factor 4: Unusual query structure (potential adversarial)
        if self._is_adversarial_structure(query):
            risk_score += 0.2
            risk_factors.append("adversarial_structure")

        # Record pattern
        self.query_patterns[user_id].append({
            "query_hash": query_hash,
            "length": len(query),
            "timestamp": datetime.utcnow()
        })

        risk_level = "high" if risk_score > 0.5 else "medium" if risk_score > 0.2 else "low"

        return risk_level, risk_factors

    def _is_systematic_pattern(self, user_id: str, query: str) -> bool:
        """Detect systematic query patterns indicative of extraction."""
        patterns = self.query_patterns[user_id][-100:]  # Last 100 queries

        if len(patterns) < 50:
            return False

        # Check for consistent length (automated queries)
        lengths = [p["length"] for p in patterns]
        length_variance = sum((l - sum(lengths)/len(lengths))**2 for l in lengths) / len(lengths)

        if length_variance < 100:  # Very consistent lengths
            return True

        return False

    def _is_adversarial_structure(self, query: str) -> bool:
        """Detect adversarial query structures."""
        # Check for unusual character patterns
        if len(set(query)) < len(query) * 0.3:  # Low character diversity
            return True

        # Check for token manipulation patterns
        if re.search(r'(.)\1{10,}', query):  # Repeated characters
            return True

        return False

theft_detector = ModelTheftDetector()

@app.route('/api/chat', methods=['POST'])
def chat():
    user = get_current_user()
    query = request.json['message']

    response = llm.generate(query)

    # Check for extraction attempt
    risk_level, factors = theft_detector.check_extraction_risk(
        user.id,
        query,
        response.text
    )

    if risk_level == "high":
        log_security_event("potential_model_extraction", {
            "user_id": user.id,
            "risk_factors": factors
        })
        # Consider throttling or blocking

    return jsonify({"response": response.text})
```

---

### Resource Monitoring and Alerting

**Implementation:**

```python
import psutil
from prometheus_client import Counter, Histogram, Gauge

# Metrics
REQUEST_COUNTER = Counter('llm_requests_total', 'Total LLM requests', ['status'])
LATENCY_HISTOGRAM = Histogram('llm_request_latency_seconds', 'Request latency')
ACTIVE_REQUESTS = Gauge('llm_active_requests', 'Active requests')
TOKEN_COUNTER = Counter('llm_tokens_total', 'Total tokens processed', ['type'])

class ResourceMonitor:
    """Monitor resource usage and trigger alerts."""

    def __init__(self, max_memory_percent: float = 80, max_cpu_percent: float = 90):
        self.max_memory = max_memory_percent
        self.max_cpu = max_cpu_percent

    def check_resources(self) -> tuple[bool, str]:
        """Check if system resources are available."""
        memory = psutil.virtual_memory()
        cpu = psutil.cpu_percent(interval=0.1)

        if memory.percent > self.max_memory:
            return False, f"Memory usage too high: {memory.percent}%"

        if cpu > self.max_cpu:
            return False, f"CPU usage too high: {cpu}%"

        return True, ""

    def get_metrics(self) -> dict:
        """Get current resource metrics."""
        return {
            "memory_percent": psutil.virtual_memory().percent,
            "cpu_percent": psutil.cpu_percent(),
            "active_requests": ACTIVE_REQUESTS._value._value,
        }

monitor = ResourceMonitor()

@app.route('/api/chat', methods=['POST'])
def chat():
    # Check resources before processing
    resources_ok, message = monitor.check_resources()
    if not resources_ok:
        REQUEST_COUNTER.labels(status='rejected_resources').inc()
        return jsonify({"error": "Service temporarily unavailable"}), 503

    ACTIVE_REQUESTS.inc()

    try:
        with LATENCY_HISTOGRAM.time():
            response = llm.generate(request.json['message'])

        REQUEST_COUNTER.labels(status='success').inc()
        TOKEN_COUNTER.labels(type='input').inc(response.usage.prompt_tokens)
        TOKEN_COUNTER.labels(type='output').inc(response.usage.completion_tokens)

        return jsonify({"response": response.text})

    except Exception as e:
        REQUEST_COUNTER.labels(status='error').inc()
        raise
    finally:
        ACTIVE_REQUESTS.dec()
```

---

### Key Prevention Rules

1. **Validate inputs** - Enforce size limits and reject malformed requests
2. **Rate limiting** - Implement per-user and per-IP rate limits
3. **Budget controls** - Set spending limits and track costs
4. **Detect extraction** - Monitor for model theft patterns
5. **Resource monitoring** - Track CPU, memory, and reject under load
6. **Output limiting** - Cap response token counts
7. **Graceful degradation** - Return errors rather than crash
8. **Alert on anomalies** - Trigger alerts for unusual patterns

**References:**
- [OWASP LLM10:2025 Unbounded Consumption](https://genai.owasp.org/llmrisk/llm10-unbounded-consumption/)
- [MITRE ATLAS T0029 - Denial of ML Service](https://atlas.mitre.org/techniques/AML.T0029)
- [MITRE ATLAS T0034 - Cost Harvesting](https://atlas.mitre.org/techniques/AML.T0034)
