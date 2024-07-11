_: {
  nixpkgs.overlays = [
    (_final: super: {
      # Prevent mbrola-voices (~650MB) from being on the live media
      espeak = super.espeak.override { mbrolaSupport = false; };

      # Makes `availableOn` fail for zfs, see <nixos/modules/profiles/base.nix>.
      # This is a workaround since we cannot remove the `"zfs"` string from `supportedFilesystems`.
      # The proper fix would be to make `supportedFilesystems` an attrset with true/false which we
      # could then `lib.mkForce false`
      # - https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix
      zfs = super.zfs.overrideAttrs (_: {
        meta.platforms = [ ];
      });
    })
  ];
}
