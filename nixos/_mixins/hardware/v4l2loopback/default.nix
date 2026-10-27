{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  isStudio = noughtyLib.hostHasTag "studio";
in
lib.mkIf (!host.is.iso && !host.is.server) {
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
    # Register a v4l2loopback device at boot on studio and desktop workstations
    kernelModules = lib.optionals (isStudio || !host.is.laptop) [
      "v4l2loopback"
    ];
  };
}
