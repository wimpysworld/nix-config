{ desktop, lib, pkgs, ... }: {
  imports = [
    ../services/cups.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot = {
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" ];
    plymouth.enable = true;
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
    };
  };

  programs.dconf.enable = true;

  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;

  systemd.services.disable-wifi-powersave = {
    wantedBy = ["multi-user.target"];
    path = [ pkgs.wirelesstools ];
    script = ''
      iwconfig wlan0 power off
    '';
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };
}
