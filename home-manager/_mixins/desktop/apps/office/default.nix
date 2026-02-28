{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf host.is.workstation (
  let
    libreofficePackage = if host.is.darwin then pkgs.libreoffice-bin else pkgs.libreoffice;
  in
  {
    home.packages = [
      pkgs.fastmail-desktop
      libreofficePackage
    ];
  }
)
