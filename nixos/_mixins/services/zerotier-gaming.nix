{ config, ... }: {
  imports = [
    ./zerotier.nix
  ];
  networking = {
    extraHosts = ''
      192.168.193.2   vader-gaming
      192.168.193.104 steamdeck-gaming
      192.168.193.217 phasma-gaming
    '';
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
