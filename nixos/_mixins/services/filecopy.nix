{ desktop, hostname, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    croc
    rclone
    wget2
    zsync
  ] ++ lib.optionals (desktop != null) [
    localsend
    persepolis
  ];
  services = {
    aria2 = {
      enable = true;
      openPorts = true;
      rpcSecret = "${hostname}";
    };
    croc = {
      enable = true;
      pass = "${hostname}";
      openFirewall = true;
    };
  };
}
