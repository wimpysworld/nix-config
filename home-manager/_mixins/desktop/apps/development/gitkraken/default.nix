{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem username installFor) {
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

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions = with pkgs; [
          vscode-marketplace.s3anmorrow.openwithkraken
        ];
      };
    };
  };
}
