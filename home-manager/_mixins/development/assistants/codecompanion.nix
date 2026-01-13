{ lib }:
# CodeCompanion.nvim Rules and Prompts (v18.x Markdown Format)
#
# Transforms *.agent.md and *.prompt.md files into CodeCompanion's rules-based composition pattern.
# CodeCompanion v18+ supports:
#   - Rules: Agent definitions loaded as context (system-level instructions)
#   - Prompts: Command definitions that reference rules via `opts.rules`
#
# Agent files become rules with the codecompanion parser for system prompt extraction.
# Command files become prompts that reference agent rules via YAML frontmatter.
#
# Expected rule format (agents):
#   # Agent Name
#
#   ## System Prompt
#   System-level instructions...
#
#   Rest of agent definition...
#
# Expected prompt format (commands):
#   ---
#   name: Display Name
#   interaction: chat
#   description: "Description text"
#   opts:
#     alias: short-name
#     rules: agent-name
#   ---
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

  # Escape ## headings in content to ### (CodeCompanion uses ## for section markers in prompts)
  # Only escape in content sections, not in rule files where ## System Prompt is required
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
  # Generate Home Manager file entries for CodeCompanion rules and prompts
  # Uses rules-based composition: agents become rules, commands reference them
  mkCodeCompanionFiles =
    {
      agentFiles,
      promptFiles,
      configDir,
    }:
    let
      rulesDir = "${configDir}/rules";
      promptsDir = "${configDir}/prompts/codecompanion";

      # Transform agent files into rules (system-level instructions)
      # Rules use the codecompanion parser to extract system prompts via ## System Prompt header
      agentRules = lib.mapAttrs' (
        filename: _:
        let
          agentName = lib.removeSuffix ".agent.md" filename;
          content = builtins.readFile (./. + "/${filename}");
          description = extractField "description" content;
          body = extractBody content; # Don't escape headings in rules - ## System Prompt is required

          # Restructure agent content for codecompanion parser
          # The parser looks for "## System Prompt" header and uses that section as system message
          ruleContent =
            if lib.hasInfix "## System Prompt" body then
              # Agent already has System Prompt section, use as-is
              body
            else
              # Wrap entire agent definition in System Prompt section
              ''
                ## System Prompt

                ${body}
              '';
        in
        {
          name = "${rulesDir}/${agentName}.md";
          value.text = ''
            # ${toTitleCase agentName}

            ${ruleContent}
          '';
        }
      ) agentFiles;

      # Transform command files into prompts that reference agent rules
      commandPrompts = lib.mapAttrs' (
        filename: _:
        let
          cmdName = lib.removeSuffix ".prompt.md" filename;
          content = builtins.readFile (./. + "/${filename}");
          description = extractField "description" content;
          agent = extractField "agent" content;
          body = escapeHeadings (extractBody content);

          # Reference agent rule if specified
          rulesOption = if agent != null then "  rules: ${agent}\n" else "";
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
            ${rulesOption}---

            ## user

            ${body}
          '';
        }
      ) promptFiles;
    in
    agentRules // commandPrompts;

  # Generate Lua configuration for rules registry
  # Returns Lua table defining all agent rules for CodeCompanion setup
  mkRulesConfig =
    {
      agentFiles,
      configDir,
    }:
    let
      rulesDir = "${configDir}/rules";
      ruleEntries = lib.mapAttrsToList (
        filename: _:
        let
          agentName = lib.removeSuffix ".agent.md" filename;
          content = builtins.readFile (./. + "/${filename}");
          description = extractField "description" content;
        in
        ''
          ${agentName} = {
            description = "${if description != null then description else "AI assistant"}",
            parser = "codecompanion",
            files = { "${rulesDir}/${agentName}.md" },
          },''
      ) agentFiles;
    in
    ''
      {
        ${lib.concatStringsSep "\n" ruleEntries}
      }'';
}
