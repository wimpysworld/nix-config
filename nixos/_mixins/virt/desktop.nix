{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    unstable.quickemu
    # for running X11 apps in distrobox
    xorg.xhost
  ];
}
