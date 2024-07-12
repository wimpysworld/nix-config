{
  config,
  desktop,
  isInstall,
  lib,
  pkgs,
  username,
  ...
}:
let
  scanningApp = if (desktop == "plasma") then pkgs.kdePackages.skanpage else pkgs.gnome.simple-scan;
in
lib.mkIf isInstall {
  # Only enables auxilary scanning support/packages if
  # config.hardware.sane.enable is true; the master control
  # - https://wiki.nixos.org/wiki/Scanners
  environment = lib.mkIf config.hardware.sane.enable { systemPackages = [ scanningApp ]; };

  hardware.sane = {
    # Hide duplicate backends
    #disabledDefaultBackends = [ "escl" ];
    enable = true;
    #extraBackends = with pkgs; [ hplipWithPlugin ];
    extraBackends = with pkgs; lib.mkIf config.hardware.sane.enable [ sane-airscan ];
  };

  users.users.${username}.extraGroups = lib.optionals config.hardware.sane.enable [ "scanner" ];
}
