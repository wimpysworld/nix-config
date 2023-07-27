{ lib, ...}: {
  boot.kernelParams = [ "fbcon=rotate:1" ];
  
  # Required for grub to properly display the boot menu.
  boot.loader.grub.gfxmodeEfi = lib.mkDefault "720x1280x32";

  fonts.fontconfig = {
    # Pixel order for rotated screen
    subpixel.rgba = lib.mkDefault "vbgr";
  };
}
