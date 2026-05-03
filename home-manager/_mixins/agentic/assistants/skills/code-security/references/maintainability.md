---
title: Code Maintainability
impact: LOW
impactDescription: Technical debt and code confusion
tags: maintainability, code-quality, python, django, flask
---

## Code Maintainability

Rules that identify code patterns leading to confusion, technical debt, or unexpected behavior. Focus areas: useless code, deprecated APIs, and code organization.

**Incorrect (Python - duplicate if condition):**

```python
if a:
    print('1')
elif a:
    print('2')
```

**Correct (Python - distinct conditions):**

```python
if a:
    print('1')
elif b:
    print('2')
```

**Incorrect (Python - identical if/else branches):**

```python
if a:
    print('1')
else:
    print('1')
```

**Correct (Python - different branches or simplified):**

```python
print('1')
```

**Incorrect (Python - unused inner function):**

```python
def A():
    def B():
        print('never used')
    return None
```

**Correct (Python - inner function called or returned):**

```python
def A():
    def B():
        print('used')
    return B()
```

**Incorrect (Python - function reference without call):**

```python
if example.is_positive:
    do_something()
```

**Correct (Python - function called with parentheses):**

```python
if example.is_positive():
    do_something()
```

**Incorrect (Django - duplicate URL paths):**

```python
urlpatterns = [
    path('path/to/view', views.example_view),
    path('path/to/view', views.other_view),
]
```

**Correct (Django - unique URL paths):**

```python
urlpatterns = [
    path('path/to/view1', views.example_view),
    path('path/to/view2', views.other_view),
]
```

**Incorrect (Flask - deprecated APIs):**

```python
from flask import json_available
blueprint = request.module
```

**Correct (Flask - modern alternatives):**

```python
from flask import Flask, request
app = Flask(__name__)
```
