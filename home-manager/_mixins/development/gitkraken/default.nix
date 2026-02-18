{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "none" ];
in
lib.mkIf (lib.elem username installFor && isWorkstation) {
  home = {
    file = {
      # https://github.com/catppuccin/gitkraken
      #  - I used the now 404: https://github.com/davi19/gitkraken
      "${config.home.homeDirectory}/.gitkraken/themes/catppuccin_mocha.jsonc".text =
        builtins.readFile ./gitkraken-catppuccin-mocha-blue-upstream.json;
    };
    # Packages that are used by some of the extensions below
    packages = with pkgs; [
      gitkraken
      gk-cli
    ];
  };
}
