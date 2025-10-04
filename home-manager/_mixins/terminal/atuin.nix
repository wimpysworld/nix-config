{
  config,
  ...
}:
{
  # Creates an infinite recursion if you do `catppuccin.atuin.enable = config.programs.atuin;`
  catppuccin.atuin.enable = true;

  programs = {
    atuin = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
      flags = [ "--disable-up-arrow" ];
      settings = {
        key_path = config.sops.secrets.atuin_key.path;
        update_check = false;
      };
    };
  };

  sops = {
    secrets = {
      atuin_key.path = "${config.home.homeDirectory}/.local/share/atuin/key";
    };
  };
}
