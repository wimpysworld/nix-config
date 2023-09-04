{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    unstable.pods
    unstable.quickemu
  ];
}
