{
  config,
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
  };
}
