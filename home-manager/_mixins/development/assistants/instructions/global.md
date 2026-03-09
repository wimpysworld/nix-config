## LSP Tools

LSP tools are available for supported file types. Use them to navigate and validate code:

- Before editing: `goToDefinition`, `goToImplementation`, `documentSymbol` to locate symbols and understand structure
- After editing: `hover` to verify types and signatures; `findReferences` to confirm no call sites are broken by renamed or moved symbols
- For deeper analysis: `workspaceSymbol`, `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`

## File Operations

Always use the built-in file manipulation tools (Read, Edit, Write or equivalent) for all file operations, regardless of target location. Never use shell commands for file creation or editing. This applies to multi-line content, configuration files, scripts, and files outside the current workspace.

## Response Standards

- British English spelling
- Syntax-highlighted code blocks with file paths
- Use hyphens or commas, never emdashes
- No preamble ("I'd be happy to help", "Great question!", "Sure, let me...")
- No summary restatements ("In summary...", "To recap...", "Overall...")
- State conclusions first, reasoning after; one statement per fact
