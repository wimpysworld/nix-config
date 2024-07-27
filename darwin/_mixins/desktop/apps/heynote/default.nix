{
  isInstall,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
{
  homebrew = {
    casks = [
      "heynote"
    ];
  };
}
