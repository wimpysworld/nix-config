{ lib, platform, ... }:
{
  imports = [
    ../_mixins/kernel/bcachefs.nix
    ../_mixins/kernel/no-zfs.nix
  ];
}
