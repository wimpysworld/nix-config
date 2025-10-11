{ lib, ... }:
{
  networking = {
    defaultGateway = "10.10.10.1";
    firewall = {
      trustedInterfaces = [ "eth0" ];
    };
    interfaces.eth0.mtu = 1462;
    interfaces.eth0.ipv4.addresses = [
      {
        address = "10.10.10.10";
        prefixLength = 24;
      }
    ];
    useDHCP = lib.mkForce false;
    usePredictableInterfaceNames = false;
  };
}
