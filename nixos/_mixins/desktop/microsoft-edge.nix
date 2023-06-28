{ pkgs, ... }: {
  environment.systemPackages = with pkgs.unstable; [
    microsoft-edge
  ];
}
