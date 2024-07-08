{ desktop, hostname, lib, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (isInstall && isWorkstation) {
  # Install snapcraft and enable snapd (for running snaps) and lxd (for building snaps)
  environment.systemPackages = with pkgs; [ snapcraft ];
  services.snap.enable = true;
  virtualisation.lxd.enable = true;
}
