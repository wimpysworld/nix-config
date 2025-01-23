{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (lib.elem username installFor) {
  home = {
    file = lib.mkIf isLinux {
      # https://github.com/catppuccin/gitkraken
      #  - I used the now 404: https://github.com/davi19/gitkraken
      "${config.home.homeDirectory}/.gitkraken/themes/catppuccin_mocha.jsonc".text = builtins.readFile ./gitkraken-catppuccin-mocha-blue-upstream.json;
    };
    packages = with pkgs; [ gitkraken ];
  };
}
