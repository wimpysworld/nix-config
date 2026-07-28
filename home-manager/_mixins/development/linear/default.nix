# Linear - issue tracking for the Linear service.
#
# There is deliberately no Catppuccin theming here. Upstream linear-tui only
# accepts the built-in theme names "linear", "high_contrast", and "color_blind"
# in `~/.linear-tui/config.json`, and it rejects any other value at startup, so
# a palette-derived theme cannot be supplied through configuration.
{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isDeveloper = noughtyLib.userHasTag "developer";
  isWorkstationDeveloper = isDeveloper && host.is.workstation;
in
lib.mkIf isWorkstationDeveloper {
  home = {
    packages = [
      pkgs.linear-tui # Terminal user interface for Linear
    ]
    # Nixpkgs builds the Linear desktop application for Darwin only.
    ++ lib.optional host.is.darwin pkgs.linear;
  };
}
