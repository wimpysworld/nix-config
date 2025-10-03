{
  config,
  lib,
  pkgs,
  ...
}:
let
  shellAliases = {
    tree = "${pkgs.eza}/bin/eza --tree";
  };
in
{
  programs = {
    bash.shellAliases = lib.mkIf config.programs.eza.enable shellAliases;
    eza = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
      extraOptions = [
        "--color=always"
        "--group-directories-first"
        "--header"
        "--time-style=long-iso"
      ];
      git = true;
      icons = "auto";
    };
    fish.shellAliases = lib.mkIf config.programs.eza.enable shellAliases;
    zsh.shellAliases = lib.mkIf config.programs.eza.enable shellAliases;
  };

}
