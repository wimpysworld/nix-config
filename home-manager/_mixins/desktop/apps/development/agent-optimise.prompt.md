---
agent: 'rosey'
description: 'Optimise Agent ⚡'
---
## Agent Prompt Optimisation

Review and optimise this agent prompt for context efficiency while preserving its core purpose:

${input:agentPrompt}

**Behaviours to Preserve:** ${input:preserveBehaviours:All core functionality}
**Target Word Count:** ${input:targetWords:400-600 words (up to 700 if complex output formats)}

Remove ineffective patterns (checklists, self-review instructions, verbose temporal breakdowns, redundant sections). Preserve output format templates and constraints—these are high-value.

Provide:
1. The optimised agent prompt
2. Changelog table (removed/preserved with rationale)
3. Final word count
