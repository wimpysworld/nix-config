{ pkgs, ... }:
{
  imports = [
    ./podman
  ];

  environment.systemPackages = with pkgs; [ ];
}
