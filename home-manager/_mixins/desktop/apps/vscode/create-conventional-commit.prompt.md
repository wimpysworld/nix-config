---
mode: 'linus'
tools: ['codebase', 'usages', 'think', 'changes', 'terminalSelection', 'terminalLastCommand', 'fetch', 'searchResults', 'search', 'github', 'memory', 'sequentialthinking', 'time', 'git_branch', 'git_checkout', 'git_create_branch', 'git_diff', 'git_diff_staged', 'git_diff_unstaged', 'git_log', 'git_show', 'git_status', 'mcp-google-cse']
description: 'Creates a Conventional Commits 1.0.0 compliant commit message from recent implementation changes'
---
Write a conventional commit message summarising the final outcome of what we've just been working on.

Please create a commit message that:
- Follows Conventional Commits 1.0.0 specification exactly
- Uses appropriate type (feat, fix, build, chore, ci, docs, perf, refactor, etc.)
- Includes proper scope if applicable
- Has clear, imperative mood description under 72 characters
- Includes body with bullet points if needed
- Adds footers for breaking changes or issue references if relevant

Output only the commit message, ready for `git commit -m`.
