{ desktop, lib, pkgs, ... }: {
  imports = [
    ../services/cups.nix
    ../services/xdg-portal.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot = {
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" ];
    plymouth.enable = true;
  };

  # X11 automation
  environment.systemPackages = with pkgs; [
    wmctrl
    xdotool
    ydotool
  ];

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
}
