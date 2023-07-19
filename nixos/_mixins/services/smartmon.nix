{ desktop, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    smartmontools
  ] ++ lib.optionals (desktop != null) [
    gsmartcontrol
  ];

  services.smartd.enable = true;
}
