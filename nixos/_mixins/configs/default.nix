{
  pkgs,
  ...
}:
let
  build-all = import ./build-all.nix { inherit pkgs; };
  build-iso = import ./build-iso.nix { inherit pkgs; };
  switch-all = import ./switch-all.nix { inherit pkgs; };
  boot-host = import ./boot-host.nix { inherit pkgs; };
  switch-host = import ./switch-host.nix { inherit pkgs; };
in
{
  environment.systemPackages = [
    build-all
    build-iso
    switch-all
    boot-host
    switch-host
  ];
}
