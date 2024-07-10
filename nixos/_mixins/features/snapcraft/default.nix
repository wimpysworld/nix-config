{ config, desktop, lib, pkgs, username, ... }:
let
  installFor = [ "martin" ];
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (lib.elem "${username}" installFor && isWorkstation) {
  # Install snapcraft and enable snapd (for running snaps) and lxd (for building snaps)
  environment.systemPackages = with pkgs; [ snapcraft ];
  services.snap.enable = true;
  virtualisation.lxd.enable = true;
  users.users.${username}.extraGroups = lib.optional (config.virtualisation.lxd.enable) "lxd";
}
