{ desktop, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    unstable.maestral
  ] ++ lib.optionals (desktop != null) [
    unstable.maestral-gui
  ];
}
