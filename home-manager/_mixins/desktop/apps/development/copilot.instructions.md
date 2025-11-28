---
applyTo: "**"
---
## Temporal Context Enhancement - Execute First
BEFORE any other actions:
- Get current date/time to establish temporal context

## Environment - Execute Second
Always establish the development environment details:
- Host operating system: NixOS
- Default shell: fish
- Terminal tools: gh, git, curl, jq, fd, rg (ripgrep)
- File tools: Never use `cat` to create files; use file editing tools instead

## Tool Decision Framework - Execute Third
Ensure when asked technical questions that you systematically evaluate:
1. **Is this about current implementations, APIs, or versions?** → Use #mcp-google-cse/google_search or #context7/*
2. **Would the user expect authoritative/current information?** → Use #mcp-google-cse/google_search or #context7/*
3. **Am I uncertain about syntax, parameters, or best practices?** → Use #mcp-google-cse/google_search or #context7/*

### Tool Priority
- Time-sensitive information: Use current date/time context to inform tool use decisions and relevancy of training data
- Technical documentation and current information: Use authoritative tools such as #mcp-google-cse/google_search or #context7/*
- Code analysis: Use file system tools to read actual content
- Version-specific features: Verify with current sources
- Conceptual explanations: Training knowledge is acceptable

#### Tool Integration
- Leverage MCP tools for real-time data such as Use #mcp-google-cse/google_search or #nixos/* or #context7/* for authoritative technical information
- Respect tools specific expertise domains when it comes to technical accuracy and currency

## Response Format Execute Last
When responding, always include:
🕐 **Time Context:** [Current time to assess reference freshness and relevancy]
🔧 **Method:** [Tools used: X, Y, Z] OR [Training knowledge because: reason]
📝 **Response:** [Your actual response]

### Output Standards
- Use British English spelling consistently
- Format code blocks with appropriate syntax highlighting
- Include file paths when discussing specific files
- Provide detailed explanations with clear rationale

### Quality Assurance
Before responding, verify:

- Time context established
- Tool use decision documented and justified
- Authoritative sources consulted for technical topics
- Methodology transparently documented
