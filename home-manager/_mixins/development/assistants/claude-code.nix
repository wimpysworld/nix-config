{ lib }:
{
  # Transform agent files for Claude Code
  # Claude Code agents require 'name' field in frontmatter (not 'agent')
  transformForClaudeCodeAgent =
    filename: content:
    let
      # Extract agent name from filename (e.g., "linus.agent.md" -> "linus")
      agentName = lib.removeSuffix ".agent.md" filename;

      lines = lib.splitString "\n" content;

      # Extract description from existing frontmatter
      descLine = lib.findFirst (line: lib.hasPrefix "description: " line) null lines;
      description =
        if descLine != null then
          # Keep the full description line as-is (with quotes if present)
          lib.removePrefix "description: " descLine
        else
          "AI assistant";

      # Split content into frontmatter and body
      splitContent = lib.splitString "---" content;
      # Format: ["", "frontmatter", "body..."]
      hasFrontmatter = (lib.length splitContent) >= 3;
      bodyParts = if hasFrontmatter then lib.drop 2 splitContent else [ content ];
      body = lib.concatStringsSep "---" bodyParts;

      # Create Claude Code-compatible frontmatter with required 'name' field
      claudeCodeYaml = ''
        ---
        name: ${agentName}
        description: ${description}
        ---'';
    in
    claudeCodeYaml + body;

  # Transform Copilot Chat syntax to Claude Code syntax
  transformForClaudeCode =
    content:
    let
      lines = lib.splitString "\n" content;

      # Extract agent name from YAML frontmatter before removing it
      agentLine = lib.findFirst (line: lib.hasPrefix "agent: " line) null lines;
      agentName =
        if agentLine != null then
          # Extract agent name from "agent: 'name'" or "agent: \"name\""
          let
            afterAgent = lib.removePrefix "agent: " agentLine;
            trimmed = lib.replaceStrings [ "'" "\"" " " ] [ "" "" "" ] afterAgent;
          in
          trimmed
        else
          null;

      # Remove 'agent:' line from YAML frontmatter
      filteredLines = lib.filter (line: !(lib.hasPrefix "agent: " line)) lines;

      # Join back and do string replacements
      withoutAgent = lib.concatStringsSep "\n" filteredLines;

      # Replace all ${input:*} patterns with $ARGUMENTS
      # Split on the input pattern
      parts = lib.splitString "\${input:" withoutAgent;
      firstPart = lib.head parts;
      restParts = lib.tail parts;

      # For each part after the first, remove everything up to and including the first }
      processRest =
        part:
        let
          splitOnClose = lib.splitString "}" part;
          # Skip the first element (the variable name/default) and keep the rest
          afterFirstClose = lib.concatStringsSep "}" (lib.tail splitOnClose);
        in
        afterFirstClose;

      # Reconstruct with $ARGUMENTS in place of the input variables
      withVariablesReplaced =
        if restParts == [ ] then
          firstPart
        else
          firstPart + lib.concatMapStringsSep "$ARGUMENTS" processRest restParts;

      # Split content into frontmatter and body
      splitContent = lib.splitString "---" withVariablesReplaced;
      # Format: ["", "frontmatter", "body..."]
      hasFrontmatter = (lib.length splitContent) >= 3;
      frontmatter = if hasFrontmatter then lib.elemAt splitContent 1 else "";
      bodyParts = if hasFrontmatter then lib.drop 2 splitContent else [ withVariablesReplaced ];
      body = lib.concatStringsSep "---" bodyParts;

      # Add @agent prefix to body if agent was specified
      finalBody = if agentName != null then "\n@${agentName} " + body else body;

      # Reconstruct with frontmatter
      transformed = if hasFrontmatter then "---" + frontmatter + "---" + finalBody else finalBody;
    in
    transformed;

  # Helper to generate Claude Code entries with transformations
  mkClaudeFiles =
    transformFn: files: suffix:
    lib.mapAttrs' (name: _: {
      name = lib.removeSuffix suffix (lib.removeSuffix ".md" name);
      value = transformFn (builtins.readFile (./. + "/${name}"));
    }) files;

  # Helper to generate Claude Code agent entries with transformations
  mkClaudeCodeAgents =
    transformFn: files:
    lib.mapAttrs' (name: _: {
      name = lib.removeSuffix ".agent" (lib.removeSuffix ".md" name);
      value = transformFn name (builtins.readFile (./. + "/${name}"));
    }) files;
}
