{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    # https://github.com/direnv/direnv/issues/1084
    sessionVariables = {
      DIRENV_WARN_TIMEOUT = "120s";
    };
  };
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableZshIntegration = config.programs.zsh.enable;
      nix-direnv = {
        enable = true;
      };
    };
    # Non-blocking direnv shell integration; runs evaluation asynchronously
    # in the background and spawns a multiplexer pane after a delay.
    # https://github.com/Mic92/direnv-instant
    direnv-instant = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions = with pkgs; [
          vscode-marketplace.mkhl.direnv
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        load_direnv = "shell_hook";
      };
    };
  };
}
