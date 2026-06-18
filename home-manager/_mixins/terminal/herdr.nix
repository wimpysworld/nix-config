{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  # Herdr reads its configuration from `~/.config/herdr/config.toml`.
  tomlFormat = pkgs.formats.toml { };
  settings = {
    # Match the repository's Catppuccin Mocha theming.
    theme.name = "catppuccin";
    ui.accent = catppuccinPalette.getColor "blue";
    ui.toast.delivery = "terminal";
  };
in
{
  config = lib.mkIf (!host.is.iso) {
    # `pkgs.herdr` comes from the `modifiedPackages` overlay, which exposes the
    # upstream flake-input build directly.
    home.packages = [
      pkgs.herdr
    ];

    xdg.configFile."herdr/config.toml".source = lib.mkDefault (
      tomlFormat.generate "herdr-config.toml" settings
    );
  };
}
