{ pkgs, ... }:
{
  imports = [
    ./network
  ];
  environment.systemPackages = with pkgs; [ ];
}
