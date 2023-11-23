{ pkgs, ... }: {
  home.packages = with pkgs; [
    nheko
  ];
}
