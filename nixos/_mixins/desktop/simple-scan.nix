{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    gnome.simple-scan
  ];
}
