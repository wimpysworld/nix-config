---
mode: 'agent'
tools: ['codebase', 'usages', 'think', 'changes', 'terminalSelection', 'terminalLastCommand', 'fetch', 'searchResults', 'search', 'runCommands', 'memory', 'sequentialthinking', 'time', 'mcp-google-cse']
description: 'Memory Context Retrieval'
---
Please use your memory graph tool to recall all relevant context for this project/conversation.

**Retrieve information about:**

### 1. **Project Context**
- Project name, purpose, and current state
- Technology stack and architecture decisions
- Conventions and patterns we've established
- Recent features implemented or discussed

### 2. **Technical Decisions**
- Key architectural choices and their rationale
- Known limitations or constraints we've identified
- Workarounds or temporary solutions in place
- Performance considerations discovered

### 3. **Work History**
- Last tasks completed
- Outstanding issues or TODOs mentioned
- Code review feedback not yet addressed
- Features we planned but haven't started

### 4. **Specific Knowledge**
- Custom functions or utilities we've created
- API endpoints or integrations configured
- Testing approaches we've adopted
- Error patterns we've encountered and solved

### 5. **Collaboration Notes**
- My preferences for code style or approach
- Specific requests or requirements I've mentioned
- Areas where I've asked for particular attention
- Any "don't do X" or "always do Y" instructions

**After retrieval**, briefly summarise:
- What relevant context you've recalled
- Any gaps in memory that might need clarification
- Which previous conversation points are most relevant to today's work

This ensures we maintain continuity and don't repeat solved problems or forget important decisions.
