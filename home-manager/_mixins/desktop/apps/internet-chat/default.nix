{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" "martin.wimpress" ];
  inherit (pkgs.stdenv) isLinux;

  slackWavebox = (inputs.xdg-override.lib.wrapPackage {
    nameMatch = [
      { case = "^https?://"; command = "wavebox"; }
    ];
  } pkgs.slack);
in
{
  home = {
    file = lib.mkIf (lib.elem username installFor) {
      "${config.home.homeDirectory}/.local/share/chatterino/Themes/mocha-blue.json".text = builtins.readFile ./chatterino-mocha-blue.json;
      "${config.home.homeDirectory}/.config/halloy/themes/catppuccin-mocha.toml".text = builtins.readFile ./halloy-catppuccin-mocha.toml;
    };

    packages =
      with pkgs;
      [ telegram-desktop ]
      ++ lib.optionals (lib.elem username installFor) [
        chatterino2
        (discord.override { withOpenASAR = true; })
      ]
      # Halloy is installed via homebrew on Darwin
      ++ lib.optionals (lib.elem username installFor && isLinux) [
        fractal
        halloy
        slackWavebox
      ];
  };

  sops = {
    secrets = lib.mkIf (lib.elem username installFor) {
      halloy_config.path = "${config.home.homeDirectory}/.config/halloy/config.toml";
    };
  };
}
