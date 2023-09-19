{ desktop, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    alsa-utils
    pulseaudio
    pulsemixer
  ] ++ lib.optionals (desktop != null) [
    pavucontrol
  ];

  # https://nixos.wiki/wiki/PipeWire
  # Debugging
  #  - pw-top                              # see live stats
  #  - journalctl -b0 --user -u pipewire   # see logs (spa resync in "bad")
  environment.etc = {
    "pipewire/pipewire.conf.d/92-fix-resync.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 1024
        default.clock.min-quantum = 1024
        default.clock.max-quantum = 1024
      }
    '';
  };

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
