{ config, ... }: {
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "e4da7455b2decfb5" ];
  };
}
