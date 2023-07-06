{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    unstable.quickemu   # track unstable
    xorg.xhost          # for running X11 apps in distrobox
  ];
}
