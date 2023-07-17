{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    tilix
  ];
}
