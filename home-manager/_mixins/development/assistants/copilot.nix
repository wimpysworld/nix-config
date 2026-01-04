{
  config,
  lib,
  agentFiles,
  ...
}:
{
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
}
