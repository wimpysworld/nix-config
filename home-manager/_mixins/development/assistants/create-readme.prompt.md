---
agent: "velma"
description: "Create README 📄"
---

## Create README

Write README.md following structure from agent definition.

### Key Requirements

- Quick start within first 30 lines
- Skip sections that don't apply
- Combine short sections

### Example Opening

<example_bad>
# ProjectX

Welcome to ProjectX! This project was created to help developers with their 
API validation needs. In this README you will find instructions...
</example_bad>

<example_good>
# ProjectX

Validate API responses against OpenAPI schemas in CI. Catch breaking changes 
before they reach production.

```bash
npm install -g projectx
projectx validate ./openapi.yaml ./api-responses/
```
</example_good>
