{ desktop, hostname, lib, pkgs, ... }:
let
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  isWorkstation = if (desktop != null) then true else false;
  # https://nixos.wiki/wiki/Steam
  isGamestation = if (hostname == "phasma" || hostname == "vader") && (isWorkstation) then true else false;
in
{
  # Enable the threadirqs kernel parameter to reduce audio latency
  # - Inpired by: https://github.com/musnix/musnix/blob/master/modules/base.nix#L56
  boot = {
    kernelParams = [ "threadirqs" ];
  };

  environment.systemPackages = with pkgs; [
    pulseaudio
  ] ++ lib.optionals (isWorkstation && isInstall) [
    pavucontrol
  ];

  hardware = {
    pulseaudio.enable = lib.mkForce false;
  };

  security = {
    # Allow members of the "audio" group to set RT priorities
    # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L87
    pam.loginLimits = [
      { domain = "@audio"; item = "memlock"; type = "-"   ; value = "unlimited"; }
      { domain = "@audio"; item = "rtprio" ; type = "-"   ; value = "99"       ; }
      { domain = "@audio"; item = "nofile" ; type = "soft"; value = "99999"    ; }
      { domain = "@audio"; item = "nofile" ; type = "hard"; value = "99999"    ; }
    ];
    rtkit.enable = true;
  };

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = isGamestation;
      jack.enable = false;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    # Expose important timers the members of the "audio" group
    # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L94
    udev.extraRules = ''
      KERNEL=="rtc0", GROUP="audio"
      KERNEL=="hpet", GROUP="audio"
      '';
  };
}
