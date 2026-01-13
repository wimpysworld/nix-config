{ lib }:
# CodeCompanion.nvim Prompt Helpers (v18.x Markdown Format)
#
# Transforms *.agent.md and *.prompt.md files into CodeCompanion's markdown format.
# CodeCompanion v18+ loads prompts from markdown files with YAML frontmatter.
#
# Expected output format:
#   ---
#   name: Display Name
#   interaction: chat
#   description: "Description text"
#   opts:
#     alias: short-name
#   ---
#
#   ## system
#   System prompt content...
#
#   ## user
#   User prompt content...
let
  # Extract body content (everything after YAML frontmatter)
  extractBody =
    content:
    let
      parts = lib.splitString "\n---\n" content;
    in
    if lib.length parts >= 2 then
      lib.trim (lib.concatStringsSep "\n---\n" (lib.drop 1 parts))
    else
      lib.trim content;

  # Extract a field value from YAML frontmatter
  extractField =
    field: content:
    let
      lines = lib.splitString "\n" content;
      fieldLine = lib.findFirst (line: lib.hasPrefix "${field}:" line) null lines;
    in
    if fieldLine != null then
      lib.trim (lib.replaceStrings [ "'" "\"" ] [ "" "" ] (lib.removePrefix "${field}:" fieldLine))
    else
      null;

  # Convert kebab-case to Title Case
  toTitleCase =
    name:
    let
      words = lib.splitString "-" name;
      capitalise = w: lib.toUpper (lib.substring 0 1 w) + lib.substring 1 (-1) w;
    in
    lib.concatStringsSep " " (map capitalise words);

  # Escape ## headings in content to ### (CodeCompanion uses ## for section markers)
  escapeHeadings =
    content:
    let
      lines = lib.splitString "\n" content;
      escapeLine =
        line:
        if lib.hasPrefix "## " line then
          "#" + line # Convert ## to ###
        else
          line;
    in
    lib.concatStringsSep "\n" (map escapeLine lines);
in
{
  # Generate Home Manager file entries for CodeCompanion prompts
  mkCodeCompanionPromptFiles =
    {
      agentFiles,
      promptFiles,
      promptsDir,
    }:
    let
      # Build map of agent name -> body content for embedding in commands
      agentBodies = lib.mapAttrs' (
        filename: _:
        let
          agentName = lib.removeSuffix ".agent.md" filename;
          content = builtins.readFile (./. + "/${filename}");
        in
        {
          name = agentName;
          value = escapeHeadings (extractBody content);
        }
      ) agentFiles;

      # Transform agent files: become system prompts
      agentEntries = lib.mapAttrs' (
        filename: _:
        let
          agentName = lib.removeSuffix ".agent.md" filename;
          content = builtins.readFile (./. + "/${filename}");
          description = extractField "description" content;
          body = escapeHeadings (extractBody content);
        in
        {
          name = "${promptsDir}/${agentName}.md";
          value.text = ''
            ---
            name: ${toTitleCase agentName}
            interaction: chat
            description: "${if description != null then description else "AI assistant"}"
            opts:
              alias: ${agentName}
              is_slash_cmd: true
            ---

            ## system

            ${body}
          '';
        }
      ) agentFiles;

      # Transform command files: become user prompts (optionally with agent system prompt)
      commandEntries = lib.mapAttrs' (
        filename: _:
        let
          cmdName = lib.removeSuffix ".prompt.md" filename;
          content = builtins.readFile (./. + "/${filename}");
          description = extractField "description" content;
          agent = extractField "agent" content;
          body = escapeHeadings (extractBody content);

          # Include agent system prompt if specified and exists
          hasAgent = agent != null && lib.hasAttr agent agentBodies;
          systemSection =
            if hasAgent then
              ''

                ## system

                ${agentBodies.${agent}}
              ''
            else
              "";
        in
        {
          name = "${promptsDir}/${cmdName}.md";
          value.text = ''
            ---
            name: ${toTitleCase cmdName}
            interaction: chat
            description: "${if description != null then description else "Custom command"}"
            opts:
              alias: ${cmdName}
              is_slash_cmd: true
            ---
            ${systemSection}
            ## user

            ${body}
          '';
        }
      ) promptFiles;
    in
    agentEntries // commandEntries;
}
