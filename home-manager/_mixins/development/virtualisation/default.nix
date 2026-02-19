{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
in
lib.mkIf (noughtyLib.isUser [ "martin" ] && host.is.linux) {
  # Authrorize X11 access in Distrobox
  home = {
    file = {
      ".distroboxrc" = lib.mkIf (config.programs.distrobox.enable && host.is.workstation) {
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
    packages = lib.optionals host.is.workstation [
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
      enable = host.is.linux;
    };
  };
}
