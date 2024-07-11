{ config, desktop, hostname, isInstall, lib, pkgs, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
  hostRGB = {
    phasma = "amd";
  };
  razerPeripherals = {
    phasma = [ "keyboard" "mouse" ];
    vader = [ "keyboard" "mouse" "controller" ];
  };
in
lib.mkIf (isInstall) {
  environment = {
    systemPackages = with pkgs; lib.optionals (builtins.hasAttr hostname razerPeripherals && isWorkstation) [
      polychromatic
    ];
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
    hardware.openrgb = lib.mkIf (builtins.hasAttr hostname hostRGB) {
      enable = true;
      motherboard = if builtins.hasAttr hostname hostRGB then
                      hostRGB.${hostname}
                    else
                      null;
      package = pkgs.openrgb-with-all-plugins;
    };
  };
}
