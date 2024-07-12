{ lib, pkgs, ... }:
{
  services = {
    gpg-agent.pinentryPackage = lib.mkForce pkgs.pinentry-gnome3;
  };
}
