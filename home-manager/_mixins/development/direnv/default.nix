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
