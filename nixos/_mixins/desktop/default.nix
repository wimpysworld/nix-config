{ desktop, lib, pkgs, ... }: {
  imports = [
    ./chromium.nix
    ../services/cups.nix
    ../services/flatpak.nix
    ../services/sane.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot = {
    kernelParams = [
      # The 'splash' arg is included by the plymouth option
      "quiet"
      "vt.global_cursor_default=0"
      "mitigations=off"
    ];
    plymouth.enable = true;
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
    };
  };

  programs = {
    dconf.enable = true;
    # Chromium is enabled by default with sane defaults.
    firefox = {
      enable = false;
    };
  };

  # Accept the joypixels license
  nixpkgs.config.joypixels.acceptLicense = true;
  
  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;
}
