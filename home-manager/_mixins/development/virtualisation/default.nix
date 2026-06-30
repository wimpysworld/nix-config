{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  virtualisationEnabled = host.is.linux && host.is.workstation;
in
lib.mkIf virtualisationEnabled {
  # Authorise X11 access in Distrobox.
  home = {
    file = {
      ".distroboxrc" = lib.mkIf config.programs.distrobox.enable {
        text = "${pkgs.xhost}/bin/xhost +si:localuser:$USER";
      };
      "Quickemu/nihilus/.keep" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
        text = "";
      };
      "Quickemu/nihilus.conf" = lib.mkIf (!(noughtyLib.hostHasTag "lima")) {
        text = ''
          #!/run/current-system/sw/bin/quickemu --vm
          guest_os="linux"
          disk_img="nihilus/disk.qcow2"
          disk_size="96G"
          iso="nihilus/nixos.iso"
        '';
      };
    };
    packages = lib.optionals host.is.workstation [
      pkgs.quickemu
    ];
  };
  programs = {
    distrobox = {
      inherit (config.services.podman) enable;
      settings = {
        container_manager = "podman";
      };
    };
  };
  services = {
    podman = {
      enable = true;
    };
  };
}
