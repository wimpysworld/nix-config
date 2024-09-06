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
{
  home = {
    file = lib.mkIf (lib.elem username installFor) {
      "${config.home.homeDirectory}/.local/share/chatterino/Themes/mocha-blue.json".text = builtins.readFile ./chatterino-mocha-blue.json;
      "${config.home.homeDirectory}/.config/halloy/themes/catppuccin-mocha.toml".text = builtins.readFile ./halloy-catppuccin-mocha.toml;
    };

    packages =
      with pkgs;
      [ unstable.telegram-desktop ]
      ++ lib.optionals (lib.elem username installFor) [
        chatterino2
        (discord.override { withOpenASAR = true; })
      ]
      # Halloy is installed via homebrew on Darwin
      ++ lib.optionals (lib.elem username installFor && isLinux) [
        fractal
        halloy
      ];
  };

  sops = {
    secrets = lib.mkIf (lib.elem username installFor) {
      halloy_config.path = "${config.home.homeDirectory}/.config/halloy/config.toml";
    };
  };
}
