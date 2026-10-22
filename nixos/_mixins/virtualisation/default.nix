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
  })

  (lib.mkIf virtualisationEnabled {
    virtualisation.spiceUSBRedirection.enable = true;
  })
]
