{ lib, ... }:
{
  networking = {
    defaultGateway = "116.202.241.193";
    defaultGateway6 = { address = "fe80::1"; interface = "eth0"; };
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
    #https://docs.hetzner.com/dns-console/dns/general/recursive-name-servers
    nameservers = lib.mkDefault [
      "185.12.64.1"
      "185.12.64.2"
      "2a01:4ff:ff00::add:1"
      "2a01:4ff:ff00::add:2"
    ];
    useDHCP = lib.mkForce false;
    usePredictableInterfaceNames = false;
  };
}
