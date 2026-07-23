{
  config,
  lib,
  noughtyLib,
  ...
}:

lib.mkIf
  (noughtyLib.isHost [
    "skrye"
    "zannah"
  ])
  {
    catppuccin.zellij.enable = config.programs.zellij.enable;

    programs.zellij = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableZshIntegration = false;
      attachExistingSession = false;
      exitShellOnExit = false;
    };
  }
