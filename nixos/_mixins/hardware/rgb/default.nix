{
  hostname,
  isInstall,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
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
lib.mkIf isInstall {
  environment = {
    systemPackages =
      with pkgs;
      lib.optionals (builtins.hasAttr hostname razerPeripherals && isWorkstation) [ polychromatic ]
      ++ lib.optionals (builtins.hasAttr hostname ratbagMice && isWorkstation) [ piper ];
  };
  hardware = {
    openrazer = lib.mkIf (builtins.hasAttr hostname razerPeripherals) {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      batteryNotifier.enable = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
  };
  services = {
    ratbagd = lib.mkIf (builtins.hasAttr hostname ratbagMice) {
      enable = true;
    };
    hardware.openrgb = lib.mkIf (builtins.hasAttr hostname hostRGB) {
      enable = true;
      motherboard = if builtins.hasAttr hostname hostRGB then hostRGB.${hostname} else null;
      package = pkgs.unstable.openrgb-with-all-plugins;
    };
  };
}
