{ lib, ... }:
{
  networking = {
    defaultGateway = "192.168.2.1";
    firewall = {
      trustedInterfaces = [ "eth0" ];
    };
    interfaces.eth0.mtu = 1462;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.2.18";
        prefixLength = 24;
      }
    ];
    useDHCP = lib.mkForce false;
    usePredictableInterfaceNames = false;
  };
}
