{ ... }:
{
  # Makes `availableOn` fail for zfs, see <nixos/modules/profiles/base.nix>.
  # This is a workaround since we cannot remove the `"zfs"` string from `supportedFilesystems`.
  # The proper fix would be to make `supportedFilesystems` an attrset with true/false which we
  # could then `lib.mkForce false`
  # - https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix
  nixpkgs.overlays = [(_final: super: {
    zfs = super.zfs.overrideAttrs(_: {
      meta.platforms = [];
    });
  })];
}
