{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    distrobox                     # Terminal container manager
  ];
}
