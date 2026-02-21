{
  config,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  libreofficePackage = if host.is.darwin then pkgs.libreoffice-bin else pkgs.libreoffice;
in
{
  home.packages = [
    pkgs.fastmail-desktop
    libreofficePackage
  ];
}
