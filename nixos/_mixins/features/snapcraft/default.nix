{ config, desktop, hostname, lib, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (isInstall && isWorkstation) {
  # Install snapcraft and enable snapd (for running snaps) and lxd (for building snaps)
  environment.systemPackages = with pkgs; [ snapcraft ];
  # Trust the lxd bridge interface, if lxd is enabled
  networking.firewall = lib.mkIf (config.virtualisation.lxd.enable) {
    trustedInterfaces = [ "lxdbr0" ];
  };
  services.snap.enable = true;
  virtualisation.lxd.enable = true;
}
