{ config, pkgs,... }:
let
  build-all = import ./build-all.nix { inherit pkgs; };
  build-host = import ./build-host.nix { inherit pkgs; };
  build-iso-console = import ./build-iso-console.nix { inherit pkgs; };
  build-iso-desktop = import ./build-iso-desktop.nix { inherit pkgs; };
  flatpak-theme = import ./flatpak-theme.nix { inherit pkgs; };
  purge-gpu-caches = import ./purge-gpu-caches.nix { inherit pkgs; };
  simple-password = import ./simple-password.nix { inherit pkgs; };
  switch-all = import ./switch-all.nix { inherit pkgs; };
  switch-host = import ./switch-host.nix { inherit pkgs; };
  unroll-url = import ./unroll-url.nix { inherit pkgs; };
in
{
  environment.systemPackages = [
    build-all
    build-host
    build-iso-console
    build-iso-desktop
    flatpak-theme
    purge-gpu-caches
    simple-password
    switch-all
    switch-host
    unroll-url
  ];
}
