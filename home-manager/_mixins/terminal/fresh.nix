{
  config,
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
  options.fresh.settings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Fresh editor settings contributed by development modules, merged into config.json.";
  };

  config = {
    fresh.settings.theme = "catppuccin-mocha.json";

    # `pkgs.fresh` comes from the `modifiedPackages` overlay, which wraps the
    # upstream flake-input build with our theme-key-resolution patch.
    home.packages = [
      pkgs.fresh
    ];

    xdg.configFile = catppuccinThemeFiles // {
      "fresh/config.json".text = lib.mkDefault (builtins.toJSON config.fresh.settings);
    };
  };
}
