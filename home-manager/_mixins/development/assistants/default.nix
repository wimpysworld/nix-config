{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  installFor = [ "martin" ];
  vscodeUserDir =
    if isLinux then
      "${config.xdg.configHome}/Code/User"
    else if isDarwin then
      "/Users/${username}/Library/Application Support/Code/User"
    else
      throw "Unsupported platform";

  # Read directory and filter for agent/prompt files
  allFiles = builtins.readDir ./.;
  agentFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".agent.md" name
  ) allFiles;
  promptFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".prompt.md" name
  ) allFiles;

  # Helper to generate VSCode file entries
  mkVscodeFiles =
    files:
    lib.mapAttrs' (name: _: {
      name = "${vscodeUserDir}/prompts/${name}";
      value.text = builtins.readFile (./. + "/${name}");
    }) files;

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
    files: suffix:
    lib.mapAttrs' (name: _: {
      name = lib.removeSuffix suffix (lib.removeSuffix ".md" name);
      value = transformForClaudeCode (builtins.readFile (./. + "/${name}"));
    }) files;

  # Helper to generate Copilot CLI file copy commands
  # Note: Copilot CLI doesn't follow symlinks due to security concerns,
  # so we copy files during activation instead of using home.file which creates symlinks
  mkCopilotFileCmds = ''
    # Copy agents
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: _:
        let
          sourcePath = ./. + "/${name}";
          targetDir = "${config.xdg.configHome}/.copilot/agents";
          targetPath = "${targetDir}/${name}";
        in
        ''
          mkdir -p ${targetDir}
          cp -f ${sourcePath} ${targetPath}
        ''
      ) agentFiles
    )}

    # Copy instructions file
    mkdir -p ${config.xdg.configHome}/.copilot
    cp -f ${./copilot.instructions.md} ${config.xdg.configHome}/.copilot/copilot-instructions.md
  '';
in
lib.mkIf (lib.elem username installFor) {
  home = {
    file = {
      # Special files
      "${vscodeUserDir}/prompts/copilot.instructions.md".text =
        builtins.readFile ./copilot.instructions.md;
      "${vscodeUserDir}/prompts/dummy.prompt.md".text = builtins.readFile ./copilot.instructions.md;

      # Claude Code rules (manual placement for 25.11 compatibility)
      "${config.home.homeDirectory}/.claude/rules/instructions.md".text =
        builtins.readFile ./copilot.instructions.md;
    }
    # VSCode: auto-generated agent and prompt files
    // mkVscodeFiles agentFiles
    // mkVscodeFiles promptFiles;
    # GitHub Copilot CLI: files copied via activation script (see home.activation below)

    # Copy Copilot CLI files as real files (not symlinks)
    # Note: Copilot CLI doesn't follow symlinks due to security concerns
    activation.copilotFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] mkCopilotFileCmds;
  };
  programs = {
    claude-code = lib.mkIf config.programs.claude-code.enable {
      # Custom agents (auto-generated from *.agent.md files)
      agents = mkClaudeFiles agentFiles ".agent";

      # Reusable commands (auto-generated from *.prompt.md files)
      commands = mkClaudeFiles promptFiles ".prompt";
    };

    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "github.copilot.chat.commitMessageGeneration.instructions" = [
            {
              file = "${vscodeUserDir}/prompts/create-conventional-commit.prompt.md";
            }
          ];
        };
      };
    };
  };
}
