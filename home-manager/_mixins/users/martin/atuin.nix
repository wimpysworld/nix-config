{
  config,
  lib,
  noughtyLib,
  ...
}:
lib.mkIf (noughtyLib.isUser [ "martin" ]) {
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
        auto_sync = true;
        key_path = config.sops.secrets.atuin_key.path;
        sync_frequency = "5m";
        update_check = false;
        sync.records = true;
        dotfiles.enabled = false;
      };
    };
  };

  sops = {
    secrets = {
      atuin_key.path = "${config.home.homeDirectory}/.local/share/atuin/key";
    };
  };
}
