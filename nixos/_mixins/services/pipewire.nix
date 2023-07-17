{ desktop, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    pulsemixer
  ] ++ lib.optionals (desktop != null) [
    pavucontrol
  ];
  hardware = {
    pulseaudio.enable = lib.mkForce false;
  };
  security.rtkit.enable = true;
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      jack.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
}
