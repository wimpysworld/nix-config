---
title: Code Best Practices
impact: LOW
impactDescription: Code quality and maintainability issues
tags: best-practices, code-quality, python, javascript
---

## Code Best Practices

This document outlines coding best practices across multiple languages. Following these patterns helps improve code quality, maintainability, and prevents common mistakes.

### File Handling - Always Close Files

**Incorrect (Python):**

```python
def func1():
    fd = open('foo')
    x = 123
```

**Correct (Python - using context manager):**

```python
def func2():
    with open('bar', encoding='utf-8') as fd:
        data = fd.read()
```

### Specify File Encoding

`open()` uses device locale encodings by default. Always specify encoding in text mode.

**Incorrect:**

```python
fd = open('foo', mode="w")
```

**Correct:**

```python
fd = open('foo', encoding='utf-8', mode="w")
```

### Network Requests Need Timeouts

Requests without a timeout will hang indefinitely if no response is received.

**Incorrect (Python):**

```python
import requests
r = requests.get(url)
```

**Correct (Python):**

```python
r = requests.get(url, timeout=30)
```

### Remove Debug Statements

Debug statements like `alert()`, `confirm()`, `prompt()`, and `debugger` should not be in production code.

**Incorrect (JavaScript):**

```javascript
var name = prompt('what is your name');
alert('your name is ' + name);
debugger;
```

### Load Modules at Top Level

Lazy loading inside functions complicates bundling and blocks requests synchronously in Node.js.

**Incorrect (JavaScript):**

```javascript
function smth() {
  const mod = require('module-name')
  return mod();
}
```

**Correct (JavaScript):**

```javascript
const mod = require('module-name')
function smth() {
  return mod();
}
```

### Secure Temporary File Creation

File creation in shared tmp directories without proper APIs can lead to security vulnerabilities.

**Incorrect (Python):**

```python
with open('/tmp/myfile.txt', 'w') as f:
    f.write(data)
```

**Correct (Python):**

```python
import tempfile
with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
    f.write(data)
```

### Cookie Security Flags

Always set `HttpOnly` and `Secure` flags on security-sensitive cookies.

**Incorrect (JavaScript/Express):**

```javascript
res.cookie('session', value);
```

**Correct (JavaScript/Express):**

```javascript
res.cookie('session', value, { httpOnly: true, secure: true });
```

### Validate Redirect URLs

Never redirect to user-provided URLs without validation to prevent open redirect vulnerabilities.

**Incorrect (JavaScript):**

```javascript
res.redirect(req.query.returnUrl);
```

**Correct (JavaScript):**

```javascript
const allowedHosts = ['example.com'];
const url = new URL(req.query.returnUrl, 'https://example.com');
if (allowedHosts.includes(url.hostname)) {
  res.redirect(url.href);
}
```

### Avoid Deprecated Libraries

Use actively maintained alternatives instead of deprecated libraries.

**Incorrect (JavaScript - Moment.js is deprecated):**

```javascript
import moment from 'moment';
```

**Correct (JavaScript - use dayjs):**

```javascript
import dayjs from 'dayjs';
```
