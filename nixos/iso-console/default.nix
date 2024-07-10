{ lib, platform, ... }:
{
  imports = [
    ../_mixins/kernel/no-zfs.nix
  ];

  # Prevent mbrola-voices (~650MB) from being on the live media
  nixpkgs.overlays = [(_final: super: {
    espeak = super.espeak.override {
      mbrolaSupport = false;
    };
  })];
}
