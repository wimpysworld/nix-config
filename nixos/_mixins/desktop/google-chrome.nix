{ pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    google-chrome
  ];
}
