{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  username = config.noughty.user.name;
  hostRGB = {
    phasma = "amd";
    vader = "amd";
  };
  ratbagMice = {
    "phasma" = [
      "g305"
    ];
    "vader" = [
      "g305"
    ];
  };
  razerPeripherals = {
    phasma-disable = [
      "keyboard"
      "mouse"
    ];
    vader-disable = [
      "keyboard"
      "mouse"
    ];
  };
in
lib.mkIf (!host.is.iso) {
  environment = {
    systemPackages =
      with pkgs;
      lib.optionals (builtins.hasAttr host.name razerPeripherals && host.is.workstation) [
        polychromatic
      ]
      ++ lib.optionals (builtins.hasAttr host.name ratbagMice && host.is.workstation) [
        piper
      ];
  };
  hardware = {
    openrazer = lib.mkIf (builtins.hasAttr host.name razerPeripherals) {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      batteryNotifier.enable = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
  };
  services = {
    ratbagd = lib.mkIf (builtins.hasAttr host.name ratbagMice) {
      enable = true;
    };
    hardware.openrgb = lib.mkIf (builtins.hasAttr host.name hostRGB) {
      enable = true;
      motherboard = if builtins.hasAttr host.name hostRGB then hostRGB.${host.name} else null;
      package = pkgs.openrgb-with-all-plugins;
    };
  };
}
