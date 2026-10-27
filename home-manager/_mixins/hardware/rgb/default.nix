{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  ratbagMice = {
    "skrye" = [
      "g305"
    ];
    "zannah" = [
      "g305"
    ];
  };
  razerPeripherals = {
    skrye-disable = [
      "keyboard"
      "mouse"
    ];
    zannah-disable = [
      "keyboard"
      "mouse"
    ];
  };
in
lib.mkIf (host.is.linux && host.is.workstation) {
  home.packages =
    with pkgs;
    lib.optionals (builtins.hasAttr host.name razerPeripherals) [
      polychromatic
    ]
    ++ lib.optionals (builtins.hasAttr host.name ratbagMice) [
      piper
    ];
}
