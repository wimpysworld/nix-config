{ desktop, hostname, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    aria2
    croc
    rclone
    wget2
    wormhole-william
    zsync
  ] ++ lib.optionals (desktop != null) [
    localsend
    motrix
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
