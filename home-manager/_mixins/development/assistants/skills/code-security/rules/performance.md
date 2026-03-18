---
title: Performance Best Practices
impact: LOW
impactDescription: Unnecessary overhead and inefficiency
tags: performance, optimization, python, javascript, django, sqlalchemy, react
---

# Performance Best Practices

This document covers performance optimizations to write efficient code. These rules identify patterns that cause unnecessary computational overhead, extra database queries, or memory inefficiency.

---

## Python

### Django - Access Foreign Keys Directly

Use `ITEM.user_id` rather than `ITEM.user.id` to prevent running an extra query. Accessing `.user.id` causes Django to fetch the entire related User object just to get the ID, when the foreign key ID is already available on the model.

**INCORRECT** - Extra query to fetch related object:
```python
def get_user_id(item):
    return item.user.id
```

**CORRECT** - Use the foreign key directly:
```python
def get_user_id(item):
    return item.user_id
```

---

### SQLAlchemy - Use count() Instead of len(all())

Using `QUERY.count()` instead of `len(QUERY.all())` sends less data to the client since the count is performed server-side. The `len(all())` approach fetches all records into memory just to count them.

**INCORRECT** - Fetches all records into memory:
```python
total = len(persons.all())
```

**CORRECT** - Count performed server-side:
```python
total = persons.count()
```

---

### SQLAlchemy - Batch Database Operations

Rather than adding one element at a time, use batch loading to improve performance. Each individual `db.session.add()` in a loop can trigger separate database operations.

**INCORRECT** - Adding one at a time in a loop:
```python
for song in songs:
    db.session.add(song)
```

**CORRECT** - Batch add all at once:
```python
db.session.add_all(songs)
```

---

## JavaScript/TypeScript

### React - Define Styled Components at Module Level

By declaring a styled component inside the render method, you dynamically create a new component on every render. This forces React to discard and re-calculate that part of the DOM subtree on each render, leading to performance bottlenecks.

**INCORRECT** - Styled component declared inside function:
```tsx
import styled from "styled-components";

function FunctionalComponent() {
  const StyledDiv = styled.div`
    color: blue;
  `
  return <StyledDiv />
}
```

**CORRECT** - Styled component declared at module level:
```tsx
import styled from "styled-components";

const StyledDiv = styled.div`
  color: blue;
`

function FunctionalComponent() {
  return <StyledDiv />
}
```

---

### Avoid Unnecessary Operations in Loops

Check array length efficiently without traversing the entire collection.

**INCORRECT** - Inefficient length check:
```javascript
if (items.length === 0) { /* empty */ }
```

**CORRECT** - Direct comparison when possible:
```javascript
if (!items.length) { /* empty */ }
```

For operations that require iterating, prefer built-in methods that short-circuit:

**INCORRECT** - Full iteration to find one item:
```javascript
const found = items.filter(x => x.id === targetId)[0];
```

**CORRECT** - Short-circuit on first match:
```javascript
const found = items.find(x => x.id === targetId);
```
