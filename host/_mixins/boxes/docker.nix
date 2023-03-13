{ ... }: {
  virtualisation = {
    containerd.enable = true;
    docker = {
      enable = true;
    };
  };
}
