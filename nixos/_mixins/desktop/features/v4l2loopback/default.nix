{ config, ... }:
{
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=13 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
  };
  security.polkit.enable = true;
}
