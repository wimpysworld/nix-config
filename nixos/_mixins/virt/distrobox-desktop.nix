{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    xorg.xhost
  ];
}
