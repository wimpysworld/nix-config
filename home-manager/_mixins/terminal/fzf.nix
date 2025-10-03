{
  config,
  ...
}:
{
  catppuccin.fzf.enable = config.programs.fzf.enable;

  programs = {
    fzf = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
    };
  };
}
