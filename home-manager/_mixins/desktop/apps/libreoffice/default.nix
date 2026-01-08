{
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  libreofficePackage = if isDarwin then pkgs.libreoffice-bin else pkgs.libreoffice;
in
{
  home.packages = [ libreofficePackage ];
}
