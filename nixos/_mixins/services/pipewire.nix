{ config, lib, pkgs, ... }:
{
  hardware = {
    pulseaudio.enable = lib.mkForce false;
  };
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
}
