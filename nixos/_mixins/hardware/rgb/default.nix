{
  config,
  lib,
  pkgs,
  ...
}:
let
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
lib.mkIf (!config.noughty.host.is.iso) {
  environment = {
    systemPackages =
      with pkgs;
      lib.optionals
        (builtins.hasAttr config.noughty.host.name razerPeripherals && config.noughty.host.is.workstation)
        [
          polychromatic
        ]
      ++
        lib.optionals
          (builtins.hasAttr config.noughty.host.name ratbagMice && config.noughty.host.is.workstation)
          [
            piper
          ];
  };
  hardware = {
    openrazer = lib.mkIf (builtins.hasAttr config.noughty.host.name razerPeripherals) {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      batteryNotifier.enable = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
  };
  services = {
    ratbagd = lib.mkIf (builtins.hasAttr config.noughty.host.name ratbagMice) {
      enable = true;
    };
    hardware.openrgb = lib.mkIf (builtins.hasAttr config.noughty.host.name hostRGB) {
      enable = true;
      motherboard =
        if builtins.hasAttr config.noughty.host.name hostRGB then
          hostRGB.${config.noughty.host.name}
        else
          null;
      package = pkgs.openrgb-with-all-plugins;
    };
  };
}
