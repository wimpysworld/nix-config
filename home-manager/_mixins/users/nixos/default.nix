{
  lib,
  noughtyLib,
  ...
}:
{
  config = lib.mkIf (noughtyLib.isUser [ "nixos" ]) {
    home.file.".face".source = ./face.png;
  };
}
