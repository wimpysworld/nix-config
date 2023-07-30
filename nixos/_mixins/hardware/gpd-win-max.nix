{ lib, ...}: {
  # Many GPD devices uses a tablet displays that are mounted rotated 90° counter-clockwise
  boot.kernelParams = [ "fbcon=rotate:1" "video=eDP-1:panel_orientation=right_side_up" ];
  
  # Required for grub to properly display the boot menu.
  boot.loader.grub.gfxmodeEfi = lib.mkDefault "800x1280x32";

  # Pixel order for rotated screen
  fonts.fontconfig.subpixel.rgba = lib.mkDefault "vbgr";
  
  # My GPD Win Max has a US keyboard layout
  console.keyMap = lib.mkForce "us";
  
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=14
    xkb-layout=us
  '';
  services.xserver.layout = lib.mkForce "us";
}
