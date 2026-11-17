{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  virtualisationEnabled = noughtyLib.isUser [ "martin" ] && host.is.workstation;
in
lib.mkMerge [
  (lib.mkIf (noughtyLib.hostHasTag "cg") {
    hardware.nvidia-container-toolkit.enable = host.gpu.hasNvidia;
    virtualisation.containers.enable = true;
    # Rootful Docker starts on demand through socket activation. Users are
    # deliberately not added to the docker group: Fence cannot restrict
    # access to the Docker socket, so membership would give every fenced
    # agent root. Use `sudo -g docker` instead.
    virtualisation.docker = {
      enable = true;
      enableOnBoot = false;
    };
    # `bootc install to-filesystem` in a privileged container compares its
    # /var/lib/containers with the host's and fails when the host lacks it.
    systemd.tmpfiles.rules = [ "d /var/lib/containers 0700 root root -" ];
  })

  (lib.mkIf virtualisationEnabled {
    virtualisation.spiceUSBRedirection.enable = true;
  })
]
