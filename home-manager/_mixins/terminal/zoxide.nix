{
  config,
  ...
}:
{
  programs = {
    zoxide = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
      # Replace cd with z and add cdi to access zi
      options = [ "--cmd cd" ];
    };
  };
}
