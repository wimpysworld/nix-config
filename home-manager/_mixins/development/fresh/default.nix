{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;

  catppuccinFresh = import ../../../../lib/fresh-catppuccin-themes.nix { inherit lib; };
  catppuccinThemeFiles = lib.mapAttrs' (
    name: theme:
    lib.nameValuePair "fresh/themes/${name}.json" {
      text = builtins.toJSON theme;
    }
  ) catppuccinFresh.themes;
in
{
  options.fresh.settings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Fresh editor settings contributed by development modules, merged into config.json.";
  };

  config = lib.mkIf host.is.workstation {
    fresh.settings.theme = "catppuccin-mocha.json";

    home.packages = [
      inputs.fresh.packages.${system}.fresh
    ];

    xdg.configFile = catppuccinThemeFiles // {
      "fresh/config.json".text = lib.mkDefault (builtins.toJSON config.fresh.settings);
    };
  };
}
