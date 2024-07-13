{ pkgs, ... }:
let
  gpg-restore = pkgs.writeShellApplication {
    name = "gpg-restore";
    runtimeInputs = with pkgs; [
      coreutils-full
      findutils
      gnupg
    ];
    text = builtins.readFile ./gpg-restore.sh;
  };
in
{
  home.packages = with pkgs; [ gpg-restore ];
}
