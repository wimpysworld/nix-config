## LSP Tools

LSP tools are available for supported file types. Use them to navigate and validate code:

- Before editing: `goToDefinition`, `goToImplementation`, `documentSymbol` to locate symbols and understand structure
- After editing: `hover` to verify types and signatures; `findReferences` to confirm no call sites are broken by renamed or moved symbols
- For deeper analysis: `workspaceSymbol`, `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`

## Web and Search Tools

Prefer MCP tools over built-in commands for all web access:

- **Search**: use `mcp__exa__web_search_exa` in preference to the built-in WebSearch tool
- **Read URLs**: use `mcp__exa__web_fetch_exa` in preference to the built-in Fetch/WebFetch tool
- **Advanced search**: use `mcp__exa__web_search_advanced_exa` when filters, date ranges, domains, categories, highlights, summaries, or subpage crawling are needed
- **Code search**: use `mcp__exa__web_search_exa`; the old Exa code-context tool is deprecated
- **Library docs**: use `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` for up-to-date library and framework documentation in preference to training knowledge
- **GitHub content**: use `gh api` to retrieve files, directory listings, and repository content from GitHub

## File Operations

Always use the built-in file manipulation tools (Read, Edit, Write or equivalent) for all file operations, regardless of target location. Never use shell commands for file creation or editing. This applies to multi-line content, configuration files, scripts, and files outside the current workspace.

## Response Standards

- British English spelling
- Syntax-highlighted code blocks with file paths
- Hyphens or commas, never emdashes
- No preamble ("I'd be happy to help", "Great question!", "Sure, let me...")
- No summary restatements ("In summary...", "To recap...", "Overall...")
- State conclusions first, reasoning after; one statement per fact
- No filler words (just, really, basically, actually, simply)
- No hedging (might, perhaps, it could be, you may want to)
- Short synonyms preferred: fix not "implement a solution for", use not "leverage", big not "extensive"
