---
agent: "velma"
description: "Update Docs 🔄"
---

## Documentation Update

Update documentation to reflect recent code changes.

### Scope

Specify what changed (or will analyse recent commits):
- **Feature**: New functionality
- **API**: Endpoint or interface changes
- **Config**: Setup or configuration changes
- **Breaking**: Incompatible changes requiring migration

### Files to Update

| Change Type | Update |
|-------------|--------|
| User-facing behaviour | README |
| API changes | API docs, inline comments |
| Setup changes | README, development guide |
| Complex logic | Inline comments explaining "why" |
| Breaking changes | README, CHANGELOG, migration guide |

### Example

<example_input>
Added rate limiting to API endpoints
</example_input>

<example_output>
**README.md** — Added "Rate Limits" section:
```markdown
## Rate Limits

- 100 requests/minute (authenticated)
- 10 requests/minute (anonymous)

Exceeding limits returns `429 Too Many Requests` with `Retry-After` header.
```

**src/middleware/rateLimit.ts** — Inline comment:
```typescript
// Sliding window, not fixed—prevents request bunching at boundaries
```
</example_output>

### Constraints

- Update existing sections rather than creating new ones
- Include code examples for new functionality
- Flag breaking changes prominently
