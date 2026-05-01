---
title: Prevent Regular Expression DoS
impact: MEDIUM
impactDescription: Service disruption through CPU exhaustion via malicious regex patterns
tags: security, redos, regex, cwe-1333, cwe-400, cwe-185
---

## Prevent Regular Expression DoS (ReDoS)

Regular Expression Denial of Service (ReDoS) occurs when attackers exploit inefficient regular expression patterns to cause excessive CPU consumption. Certain regex patterns with nested quantifiers or overlapping alternatives can experience "catastrophic backtracking" when matched against malicious input, causing the regex engine to take exponential time to evaluate.

Common vulnerable patterns include:
- Nested quantifiers: `(a+)+`, `(a*)*`, `(a|a)+`
- Overlapping alternatives: `(a|aa)+`
- Unbounded repetition with overlap: `.*.*`

### Language: JavaScript / TypeScript

**Incorrect (vulnerable ReDoS pattern):**
```javascript
const re = new RegExp("([a-z]+)+$", "i");

var emailRegex = /^\w+([-_+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$/;
emailRegex.test(userInput);
```

**Correct (safe regex patterns):**
```javascript
// Use atomic patterns without nested quantifiers
const safeRegex = /^[a-z]+$/i;

// Or use a library with ReDoS protection
import { RE2 } from 're2';
const re = new RE2("([a-z]+)+$");
```

---

**Incorrect (non-literal RegExp with user input):**
```javascript
function searchHandler(userPattern) {
  const reg = new RegExp("\\w+" + userPattern);
  return reg.exec(data);
}
```

**Correct (hardcoded regex patterns):**
```javascript
function searchHandler(userInput) {
  const reg = new RegExp("\\w+");
  return reg.exec(userInput);
}
```

---

**Incorrect (incomplete string sanitization):**
```javascript
function escapeQuotes(s) {
  return s.replace("'", "''");  // Only replaces first occurrence
}
```

**Correct (use regex with global flag):**
```javascript
function escapeQuotes(s) {
  return s.replace(/'/g, "''");  // Replaces all occurrences
}
```

**References:**
- [OWASP ReDoS](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS)
- [Regular-Expressions.info ReDoS](https://www.regular-expressions.info/redos.html)
- CWE-1333: Inefficient Regular Expression Complexity

---

### Language: Python

**Incorrect (inefficient regex pattern):**
```python
import re

redos_pattern = r"^(a+)+$"
data = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaX"

pattern = re.compile(redos_pattern)
pattern.match(data)  # Catastrophic backtracking
```

**Correct (safe regex patterns):**
```python
import re

safe_pattern = r"^a+$"
data = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaX"

pattern = re.compile(safe_pattern)
pattern.match(data)  # Fast failure, no backtracking
```

**Mitigation strategies:**
```python
# Use regex timeout (Python 3.11+)
import re
re.match(pattern, data, timeout=1.0)

# Or use google-re2 library for linear-time matching
import re2
re2.match(r"^(a+)+$", data)
```

**References:**
- [Python re module](https://docs.python.org/3/library/re.html)
- CWE-1333: Inefficient Regular Expression Complexity

---

## General Mitigation Strategies

1. **Avoid nested quantifiers**: Never use patterns like `(a+)+` or `(.*)*`
2. **Use atomic groups or possessive quantifiers** when available
3. **Set timeouts**: Use regex timeout mechanisms to limit execution time
4. **Use safe regex libraries**: RE2 (Go/Python/JS) guarantees linear-time matching
5. **Validate user input length**: Limit input size before regex matching
6. **Test with ReDoS analyzers**: Use tools like `safe-regex` or `recheck`

**References:**
- CWE-1333: Inefficient Regular Expression Complexity
- CWE-400: Uncontrolled Resource Consumption
- [OWASP ReDoS](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS)
- [Regular-Expressions.info ReDoS](https://www.regular-expressions.info/redos.html)
