{ lib, ... }:
let
  # https://developers.cloudflare.com/1.1.1.1/ip-addresses/
  cloudflareDns = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];
  # https://docs.hetzner.com/dns-console/dns/general/recursive-name-servers
  hetznerDns = [
    "185.12.64.1"
    "185.12.64.2"
    "2a01:4ff:ff00::add:1"
    "2a01:4ff:ff00::add:2"
  ];
in
{
  networking = {
    defaultGateway = "116.202.241.193";
    defaultGateway6 = { address = "fe80::1"; interface = "eth0"; };
    firewall = {
      allowedTCPPorts = [ 80 443 ];
    };
    interfaces.eth0.ipv4.addresses = [
      {
        address = "116.202.241.253";
        prefixLength = 26;
      }
    ];
    interfaces.eth0.ipv6.addresses = [
      {
        address = "2a01:4f8:241:3f6d::1";
        prefixLength = 64;
      }
    ];
    nameservers = lib.mkForce hetznerDns;
    useDHCP = lib.mkForce false;
    usePredictableInterfaceNames = false;
  };
  services.resolved = {
    fallbackDns = lib.mkForce cloudflareDns;
    dnsovertls = lib.mkForce "false";
  };
}
