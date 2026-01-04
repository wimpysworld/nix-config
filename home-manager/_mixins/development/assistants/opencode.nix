{
  config ? { },
  lib,
  agentFiles ? { },
  ...
}:
let
  # General permission profile for all agents
  # - edit: allow - Agents can edit files without prompting (expected for coding)
  # - bash: ask - Prompts before running commands (safety for destructive ops)
  # - webfetch: allow - Can fetch web content freely (research capability)
  # - skill: ask - Prompts before loading third-party skills
  # - doom_loop: ask - Prompts if infinite loop detected
  # - external_directory: ask - Prompts for files outside working directory
  generalPermissions = {
    edit = "allow";
    bash = "ask";
    webfetch = "allow";
    skill = "ask";
    doom_loop = "ask";
    external_directory = "ask";
  };

  # Generate YAML permission block from profile
  mkPermissionYaml =
    permissions:
    let
      mkEntry = key: value: "    ${key}: ${value}";
      entries = lib.mapAttrsToList mkEntry permissions;
    in
    lib.concatStringsSep "\n" ([ "permissions:" ] ++ entries);
in
{
  # Transform command files for OpenCode
  # OpenCode commands: preserve agent field in frontmatter to specify which agent executes the command
  # Simply pass through the content as-is since we no longer use input variables
  transformForOpenCodeCommand = content: content;

  # Transform agent files for OpenCode
  # OpenCode agents: subagents (mode: subagent) can only be @mentioned, not listed in Tab cycling
  # For agents to appear in /agents list and Tab cycling, use mode: primary or omit mode entirely
  transformForOpenCodeAgent =
    filename: content:
    let
      lines = lib.splitString "\n" content;

      # Extract description from existing frontmatter
      descLine = lib.findFirst (line: lib.hasPrefix "description: " line) null lines;
      description =
        if descLine != null then
          # Remove "description: " prefix and quotes
          lib.replaceStrings [ "description: " "'" "\"" ] [ "" "" "" ] descLine
        else
          "AI assistant";

      # Split content into frontmatter and body
      splitContent = lib.splitString "---" content;
      # Format: ["", "frontmatter", "body..."]
      hasFrontmatter = (lib.length splitContent) >= 3;
      bodyParts = if hasFrontmatter then lib.drop 2 splitContent else [ content ];
      body = lib.concatStringsSep "---" bodyParts;

      # Create OpenCode-compatible frontmatter with permissions
      # Omit mode entirely so agents appear in list (mode: subagent prevents listing)
      opencodeYaml = ''
        ---
        description: ${description}
        ${mkPermissionYaml generalPermissions}
        ---'';
    in
    opencodeYaml + body;

  # Helper to generate OpenCode command entries with transformations
  mkOpenCodeCommands =
    transformFn: files:
    lib.mapAttrs' (name: _: {
      name = lib.removeSuffix ".prompt" (lib.removeSuffix ".md" name);
      value = transformFn (builtins.readFile (./. + "/${name}"));
    }) files;

  # Helper to generate OpenCode agent entries
  mkOpenCodeAgents =
    transformFn: files:
    lib.mapAttrs' (name: _: {
      name = lib.removeSuffix ".agent" (lib.removeSuffix ".md" name);
      value = transformFn name (builtins.readFile (./. + "/${name}"));
    }) files;
}
