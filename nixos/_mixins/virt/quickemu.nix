{ pkgs, ... }: {
  # tracks unstable
  environment.systemPackages = with pkgs.unstable; [
    quickemu
  ];
}
