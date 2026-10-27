{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
in
lib.mkIf (!host.is.iso && !host.is.server) {
  # Only enables auxilary scanning support/packages if
  # config.hardware.sane.enable is true; the master control
  # - https://wiki.nixos.org/wiki/Scanners
  hardware.sane = {
    # Hide duplicate backends
    #disabledDefaultBackends = [ "escl" ];
    enable = true;
    #extraBackends = with pkgs; [ hplipWithPlugin ];
    extraBackends = with pkgs; lib.mkIf config.hardware.sane.enable [ sane-airscan ];
  };

  users.users.${username}.extraGroups = lib.optionals config.hardware.sane.enable [ "scanner" ];
}
