{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    distrobox
  ];
  virtualisation = {
    containerd.enable = true;
    docker = {
      enable = true;
    };
  };
}
