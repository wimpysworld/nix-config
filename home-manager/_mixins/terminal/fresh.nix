{
  lib,
  pkgs,
  ...
}:
let
  catppuccinFresh = import ../../../lib/fresh-catppuccin-themes.nix { inherit lib; };
  catppuccinThemeFiles = lib.mapAttrs' (
    name: theme:
    lib.nameValuePair "fresh/themes/${name}.json" {
      text = builtins.toJSON theme;
    }
  ) catppuccinFresh.themes;
in
{
  config = {
    programs.fresh-editor = {
      enable = true;
      package = pkgs.unstable.fresh-editor;
      settings.theme = "catppuccin-mocha.json";
    };

    xdg.configFile = catppuccinThemeFiles;
  };
}
