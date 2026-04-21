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
      enableFishIntegration = false; # HM stable 25.11 makes enableFishIntegration read-only; erased in fish init below
      enableZshIntegration = config.programs.zsh.enable;
    };
    fish = lib.mkIf config.programs.fish.enable {
      interactiveShellInit = lib.mkBefore ''
        # Prevent standard direnv hook from firing; direnv-instant handles this
        functions --erase __direnv_export_eval 2>/dev/null
        functions --erase __direnv_cd_hook 2>/dev/null
      '';
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        load_direnv = "shell_hook";
      };
    };
  };
}
