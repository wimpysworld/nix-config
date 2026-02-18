{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && isLinux) {
  # Authrorize X11 access in Distrobox
  home = {
    file = {
      ".distroboxrc" = lib.mkIf (config.programs.distrobox.enable && config.noughty.host.is.workstation) {
        text = "${pkgs.xorg.xhost}/bin/xhost +si:localuser:$USER";
      };
      "Quickemu/nixos-console/.keep" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
        text = "";
      };
      "Quickemu/nixos-console.conf" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
        text = ''
          #!/run/current-system/sw/bin/quickemu --vm
          guest_os="linux"
          disk_img="nixos-console/disk.qcow2"
          disk_size="96G"
          iso="nixos-console/nixos.iso"
        '';
      };
    };
    packages = lib.optionals config.noughty.host.is.workstation [
      pkgs.quickemu
    ];
  };
  programs = {
    distrobox = {
      enable = config.services.podman.enable;
      settings = {
        container_manager = "podman";
      };
    };
  };
  services = {
    podman = {
      enable = isLinux;
    };
  };
}
