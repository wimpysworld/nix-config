{ desktop, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ] ++ lib.optionals (desktop != null) [
    gsmartcontrol
  ];

  services.smartd.enable = true;
}
