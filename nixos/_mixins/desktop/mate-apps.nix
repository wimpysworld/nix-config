{ pkgs, ... }: {
    # Add some packages to complete the MATE desktop
    systemPackages = with pkgs; [
      celluloid
      gnome.gucharmap
      gnome-firmware
      gnome.simple-scan
      gthumb
    ];
  };

  # Enable some programs to provide a complete desktop
  programs = {
    gnome-disks.enable = true;
    seahorse.enable = true;
  };
}
