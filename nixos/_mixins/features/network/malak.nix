{ lib, ... }:
{
  # enp0s31f6
  #Broadcast: 116.202.241.255
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
    useDHCP = lib.mkForce false;
    usePredictableInterfaceNames = false;
  };
}
