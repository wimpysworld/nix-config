{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
  inherit (pkgs.stdenv) isLinux;

  slackWavebox = (
    inputs.xdg-override.lib.wrapPackage {
      nameMatch = [
        {
          case = "^https?://";
          command = "wavebox";
        }
      ];
    } pkgs.slack
  );
in
{
  catppuccin.halloy.enable = true;
  home = {
    packages =
      with pkgs;
      [ telegram-desktop ]
      ++ lib.optionals (lib.elem username installFor) [
        (discord.override { withOpenASAR = true; })
      ]
      # Halloy is installed via homebrew on Darwin
      ++ lib.optionals (lib.elem username installFor && isLinux) [
        fractal
        halloy
        slackWavebox
        zoom-us
      ];
  };

  sops = {
    secrets = lib.mkIf (lib.elem username installFor) {
      halloy_config.path = "${config.home.homeDirectory}/.config/halloy/config.toml";
    };
  };
}
