{
  config,
  ...
}:
{
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
