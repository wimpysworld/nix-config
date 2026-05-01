---
title: Code Correctness
impact: MEDIUM
impactDescription: Runtime errors and unexpected behavior
tags: correctness, bugs, python, javascript, java, go, c
---

# Code Correctness Rules

Common coding mistakes that cause runtime errors, unexpected behavior, or logic issues.

---

## Python

### Mutable Default Arguments

Python only instantiates default arguments once. Mutating them affects all future calls.

**INCORRECT**:
```python
def append_func(default=[]):
    default.append(5)
```

**CORRECT**:
```python
def append_func(default=None):
    if default is None:
        default = []
    default.append(5)
```

### Modifying Collections While Iterating

**INCORRECT**:
```python
items = [1, 2, 3, 4]
for i in items:
    items.pop(0)
```

**CORRECT**:
```python
for i in list(items):  # Iterate over a copy
    items.pop(0)
```

### Suppressed Exceptions in Finally

Using `break`, `continue`, or `return` in `finally` suppresses exceptions.

**INCORRECT**:
```python
try:
    raise ValueError()
finally:
    break  # Suppresses the exception!
```

### Raising Non-Exceptions

**INCORRECT**:
```python
raise "error"
```

**CORRECT**:
```python
raise Exception("error")
```

### String Concatenation in Lists

Missing commas cause implicit string concatenation.

**INCORRECT**:
```python
bad = ["a" "b" "c"]  # Results in ["abc"]
```

**CORRECT**:
```python
good = ["a", "b", "c"]
```

---

## JavaScript

### Missing Template String $

**INCORRECT**:
```javascript
return `value is {x}`  // Missing $
```

**CORRECT**:
```javascript
return `value is ${x}`
```

---

## Go

### Loop Pointer Export

Loop variables are shared across iterations.

**INCORRECT**:
```go
for _, val := range values {
    funcs = append(funcs, func() {
        fmt.Println(&val)  // Same pointer for all!
    })
}
```

**CORRECT**:
```go
for _, val := range values {
    val := val  // Create new variable
    funcs = append(funcs, func() {
        fmt.Println(&val)
    })
}
```

### Integer Overflow from Atoi

**INCORRECT**:
```go
bigValue, _ := strconv.Atoi("2147483648")
value := int16(bigValue)  // Overflow!
```

**CORRECT**: Use `strconv.ParseInt` with correct bit size.

---

## Java

### String Comparison with ==

**INCORRECT**:
```java
if (a == "hello") return 1;
```

**CORRECT**:
```java
if ("hello".equals(a)) return 1;
```

### Assignment in Condition

**INCORRECT**:
```java
if (myBoolean = true) {  // Assignment, not comparison!
```

**CORRECT**:
```java
if (myBoolean) {
```

---

## C

### ato* Functions

The `ato*()` functions cause undefined behavior on overflow.

**INCORRECT**:
```c
int i = atoi(buf);
```

**CORRECT**:
```c
long l = strtol(buf, NULL, 10);
```

---

## Bash

### Unquoted Variable Expansion

Unquoted variables split on whitespace.

**INCORRECT**:
```bash
exec $foo
```

**CORRECT**:
```bash
exec "$foo"
```

---

## Other Languages

### Scala: indexOf > 0 Bug

**INCORRECT**:
```scala
if (list.indexOf(item) > 0)  // Misses first element!
```

**CORRECT**:
```scala
if (list.indexOf(item) >= 0)
```

### Elixir: Atom Exhaustion

Atoms are never garbage collected. Use `String.to_existing_atom` instead of `String.to_atom`.

### OCaml: Physical vs Structural Equality

Use `=` not `==` for value comparison, `<>` not `!=` for inequality.
