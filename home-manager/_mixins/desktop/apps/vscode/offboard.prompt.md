---
mode: 'agent'
tools: ['codebase', 'usages', 'think', 'problems', 'changes', 'testFailure', 'terminalSelection', 'terminalLastCommand', 'fetch', 'findTestFiles', 'searchResults', 'githubRepo', 'search', 'new', 'google-search', 'memory', 'sequentialthinking', 'time']
description: 'Offboard 📤'
---
## AI Engineer Handover Request

I need you to create a thorough handover document for the next AI engineer who will continue work on this project. This document should enable them to seamlessly pick up where we've left off without needing to reverse-engineer our decisions or rediscover limitations we've already identified.

Please structure your handover document with the following sections:

### 1. Project Overview & Context
- **Project Description**: What we're building and its core purpose
- **Current State**: What's been completed vs what remains
- **Key Decisions Made**: Architectural choices, technology selections, and the rationale behind them
- **Success Criteria**: How we define completion and quality standards

### 2. Codebase & Structure
- **Repository Location**: Where the code lives (if established)
- **Directory Structure**: Complete breakdown of the project organisation
- **File Naming Conventions**: Patterns we've established
- **Code Style Guidelines**: Formatting, commenting standards, and any linting rules
- **Dependencies**: Complete list with versions and why each was chosen

### 3. Technical Implementation Details
- **Architecture Diagram**: Visual or textual representation of system components
- **Data Flow**: How information moves through the system
- **Key Algorithms/Logic**: Detailed explanation of core functionality
- **Integration Points**: APIs, services, or systems we interface with
- **Configuration Management**: Environment variables, config files, and their purposes

### 4. Development Environment
- **Required Tools**: IDEs, build tools, testing frameworks with specific versions
- **Setup Instructions**: Step-by-step guide to get a working development environment
- **Common Commands**: Build, test, deploy, and debug commands
- **Environment-Specific Considerations**: Differences between dev/staging/production

### 5. Known Limitations & Constraints
- **Technical Limitations**: What we've discovered doesn't work or has issues
- **Workarounds Implemented**: Temporary solutions and why they exist
- **Performance Bottlenecks**: Identified issues and potential solutions
- **Platform/Tool Limitations**: Restrictions we've encountered and must work within
- **Security Considerations**: Any security constraints or requirements

### 6. Outstanding Features Implementation Plan
For each remaining feature, provide:
- **Feature Description**: What it should accomplish
- **Acceptance Criteria**: How we'll know it's complete
- **Technical Approach**: Recommended implementation strategy with rationale
- **Step-by-Step Implementation**:
  1. Prerequisites (what must be in place first)
  2. Detailed implementation steps with code examples where helpful
  3. Testing approach
  4. Integration steps
- **Estimated Complexity**: Simple/Medium/Complex with justification
- **Potential Challenges**: What might go wrong and mitigation strategies
- **Dependencies**: Other features or systems this relies upon

### 7. Testing Strategy
- **Current Test Coverage**: What's tested and what isn't
- **Testing Frameworks Used**: Tools and their configuration
- **Test Data**: Where it lives and how to generate/refresh it
- **Critical Test Scenarios**: Must-pass tests and why they're important

### 8. Documentation & References
- **Existing Documentation**: What's been written and where to find it
- **Key References**: Articles, documentation, or resources we've relied upon
- **Design Decisions Log**: Why we chose approach A over approach B
- **Useful Code Snippets**: Reusable patterns we've developed

### 9. Communication & Collaboration Notes
- **Stakeholder Expectations**: What's been promised and to whom
- **Communication Patterns**: How updates have been shared
- **Feedback Received**: Important feedback that shaped the project
- **Open Questions**: Unresolved decisions that need attention

### 10. Quick Start Guide for Next Engineer
- **First Day Tasks**: Exactly what to do to get oriented
- **First Week Goals**: Realistic targets for initial productivity
- **Key Contacts**: Who to reach out to for different types of questions
- **Where to Start**: Recommended first feature to tackle and why

### Additional Requirements:
- Include actual code examples wherever they would clarify implementation
- Highlight any "gotchas" or non-obvious behaviours with ⚠️ WARNING markers
- Mark critical information with 📌 IMPORTANT tags
- Include timestamps or version numbers where relevant
- If we've attempted something that failed, document why it didn't work
- Be explicit about assumptions we're making
- Include any relevant diagrams, even if ASCII art

Please be exhaustively thorough - it's better to over-document than to leave the next engineer guessing. Assume they're technically competent but have zero context about our specific project decisions and discoveries.
