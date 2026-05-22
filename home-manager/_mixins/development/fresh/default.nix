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

    xdg.configFile = {
      "fresh/config.json".text = lib.mkDefault (builtins.toJSON config.fresh.settings);

      "fresh/themes/catppuccin-frappe.json".source = ./themes/catppuccin-frappe.json;
      "fresh/themes/catppuccin-latte.json".source = ./themes/catppuccin-latte.json;
      "fresh/themes/catppuccin-macchiato.json".source = ./themes/catppuccin-macchiato.json;
      "fresh/themes/catppuccin-mocha.json".source = ./themes/catppuccin-mocha.json;
    };
  };
}
