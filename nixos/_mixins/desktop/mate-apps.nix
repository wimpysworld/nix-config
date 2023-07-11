{ pkgs, ... }: {
  imports = [
    ../services/flatpak.nix
    ../services/sane.nix
  ];

  # Add some packages to complete the MATE desktop
  environment.systemPackages = with pkgs; [
    celluloid
    gnome.gucharmap
    gnome-firmware
    gthumb
  ];

  # Enable some programs to provide a complete desktop
  programs = {
    gnome-disks.enable = true;
    seahorse.enable = true;
  };
}
