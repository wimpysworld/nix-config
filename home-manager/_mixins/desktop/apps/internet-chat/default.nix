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
  matrixClient = if isLinux then pkgs.fractal else pkgs.cinny-desktop;
in
{
  home = {
    file = lib.mkIf (lib.elem username installFor) {
      "${config.home.homeDirectory}/.local/share/chatterino/Themes/mocha-blue.json".text = builtins.readFile ./chatterino-mocha-blue.json;
      "${config.home.homeDirectory}/.config/halloy/themes/catppuccin-mocha.toml".text = builtins.readFile ./halloy-catppuccin-mocha.toml;
    };

    packages =
      [ pkgs.unstable.telegram-desktop ]
      ++ lib.optionals (lib.elem username installFor) [
        matrixClient
        pkgs.chatterino2
        (pkgs.discord.override { withOpenASAR = true; })
      ]
      # Install Halloy for Darwin via Homebrew
      ++ lib.optionals (lib.elem username installFor && isLinux) [
        pkgs.halloy
      ];
  };

  sops = {
    secrets = lib.mkIf (lib.elem username installFor) {
      halloy_config.path = "${config.home.homeDirectory}/.config/halloy/config.toml";
    };
  };
}
