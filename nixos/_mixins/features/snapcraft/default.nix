{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (lib.elem "${username}" installFor && isWorkstation) {
  services.snap.enable = true;

  # I've stopped using snapcraft and lxd on NixOS
  # because I now use an Ubuntu guest for building snaps.
  # Install snapcraft and enable snapd (for running snaps) and lxd (for building snaps)
  #environment.systemPackages = with pkgs; [ snapcraft ];

  # lxd in Nixpkgs errorneously disables unified cgroup hierarchy.
  # LXD has had support for cgroups v2 since since 2020.
  #systemd.enableUnifiedCgroupHierarchy = lib.mkForce true;
  #virtualisation.lxd.enable = true;
  #users.users.${username}.extraGroups = lib.optional config.virtualisation.lxd.enable "lxd";
}
