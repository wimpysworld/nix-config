{ pkgs, ... }:
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      grub.enable = true;
      grub.device = "nodev";
      grub.memtest86.enable = true;
      grub.theme = pkgs.nixos-grub2-theme;
      grub.useOSProber = true;
      timeout = 10;
    };
  };
}
