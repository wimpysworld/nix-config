---
mode: 'dilbert'
tools: ['codebase', 'usages', 'think', 'problems', 'changes', 'testFailure', 'terminalSelection', 'terminalLastCommand', 'fetch', 'findTestFiles', 'searchResults', 'githubRepo', 'editFiles', 'runNotebooks', 'search', 'runCommands', 'runTasks', 'context7', 'memory', 'Ref', 'sequentialthinking', 'time']
description: 'Implementation Plan Request'
---
Now that you've reviewed the handover document and we've clarified any questions, please create a detailed implementation plan optimised for AI-assisted development.

**Structure your plan with:**

### 1. **Feature Breakdown**
Decompose each outstanding feature into atomic tasks that can be:
- Completed in a single conversation session
- Tested independently
- Reviewed without needing full system context
- Rolled back if needed without breaking other components

### 2. **Step-by-Step Task Sequence**
For each task, provide:
- **Task ID & Name**: [TASK-001: Descriptive name]
- **Dependencies**: What must be complete before this
- **Scope**: Exactly what files/functions will be modified
- **Success Criteria**: How we verify it's working
- **Estimated Complexity**: Simple/Medium/Complex
- **Review Points**: What specifically needs human review

### 3. **Implementation Chunks**
Group related tasks into reviewable chunks:
- 3-5 tasks per chunk maximum
- Each chunk should produce working, testable code
- Clear checkpoint where we can assess progress
- Natural pause points for context switching

### 4. **Risk Mitigation**
- Identify high-risk tasks that need extra scrutiny
- Suggest where we should create backups or branches
- Flag areas where the AI context window might be challenged
- Highlight tasks requiring human decision-making

### 5. **Optimal Collaboration Format**
Specify for each task:
- Whether to show full file or just relevant sections
- What context from other files is essential
- Expected input/output examples
- Any specific testing commands to run

Present this as a numbered checklist we can work through systematically, with clear "commit points" where we save progress. Assume each conversation might have a fresh AI instance, so make each step self-contained with necessary context.
