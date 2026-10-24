# Provides the UDisks2 system service that the Home Manager removable-media
# module uses to mount drives. Ubuntu ships UDisks2 and polkit, so generic
# Linux hosts need only the Home Manager module.
{ config, lib, ... }:
let
  inherit (config.noughty) host;
in
lib.mkIf (host.is.workstation && !host.is.iso) {
  services.udisks2.enable = true;
}
