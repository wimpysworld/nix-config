{ lib, modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../_mixins/services/pipewire.nix
  ];

  swapDevices = [{
    device = "/swap";
    size = 1024;
  }];

  console = {
    earlySetup = true;
    # Pixel sizes of the font: 12, 14, 16, 18, 20, 22, 24, 28, 32
    # Followed by 'n' (normal) or 'b' (bold)
    font = "ter-powerline-v18n";
    packages = [ pkgs.terminus_font pkgs.powerline-fonts ];
  };

  environment.systemPackages = with pkgs; [ ];

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };

  services = {
    xserver.videoDrivers = [ ];
  };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
