{ config, ... }: {
  imports = [
    ./zerotier.nix
  ];
  networking = {
    firewall = {
      trustedInterfaces = [
        "ztrfyc7hsl"
      ];
    };
  };
  services.zerotierone = {
    joinNetworks = [
      "3efa5cb78a7329c1"
    ];
  };
}
