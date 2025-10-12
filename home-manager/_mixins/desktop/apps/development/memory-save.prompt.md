---
mode: 'agent'
tools: ['codebase', 'usages', 'think', 'changes', 'terminalSelection', 'terminalLastCommand', 'fetch', 'searchResults', 'search', 'runCommands', 'memory', 'sequentialthinking', 'time']
description: 'Memory Commit Request'
---
Please commit the following important information from our session to your memory graph for future reference:

**Store these elements:**

### 1. **Decisions Made**
- Architectural or design choices with rationale
- Technology selections (libraries, tools, frameworks)
- Trade-offs evaluated and final decisions
- Deferred improvements and why we postponed them

### 2. **Implementation Details**
- Custom solutions or algorithms developed
- Workarounds for limitations discovered
- Performance optimizations applied
- Error handling strategies adopted

### 3. **Project Evolution**
- Features completed today with their approach
- Changes to project structure or conventions
- New dependencies added and their purpose
- Test cases or validation methods established

### 4. **Context & Constraints**
- New limitations or edge cases discovered
- External requirements or dependencies identified
- Security considerations discussed
- Platform-specific behaviours encountered

### 5. **Future Work**
- TODOs and planned improvements
- Technical debt acknowledged
- Features discussed but not yet started
- Questions that need research or clarification

### 6. **Collaboration Preferences**
- Any specific feedback I've given
- Coding patterns I've approved or rejected
- Communication style preferences noted
- Review points I've emphasised

**Commit Format:**
Tag memories with: `[Project Name] - [Date] - [Category]` for easy retrieval

**Priority**: Focus on decisions and discoveries that would be expensive to rediscover or that significantly affect future implementation.
