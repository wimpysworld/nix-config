{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  username = config.noughty.user.name;
  scanningApp = if (host.desktop == "plasma") then pkgs.kdePackages.skanpage else pkgs.simple-scan;
in
lib.mkIf (!host.is.iso) {
  # Only enables auxilary scanning support/packages if
  # config.hardware.sane.enable is true; the master control
  # - https://wiki.nixos.org/wiki/Scanners
  environment = lib.mkIf (config.hardware.sane.enable && host.is.workstation) {
    systemPackages = [ scanningApp ];
  };

  hardware.sane = {
    # Hide duplicate backends
    #disabledDefaultBackends = [ "escl" ];
    enable = true;
    #extraBackends = with pkgs; [ hplipWithPlugin ];
    extraBackends = with pkgs; lib.mkIf config.hardware.sane.enable [ sane-airscan ];
  };

  users.users.${username}.extraGroups = lib.optionals config.hardware.sane.enable [ "scanner" ];
}
