{
  pkgs,
  ...
}:
let
  build-all = import ./build-all.nix { inherit pkgs; };
  switch-all = import ./switch-all.nix { inherit pkgs; };
  boot-host = import ./boot-host.nix { inherit pkgs; };
in
{
  environment.systemPackages = [
    build-all
    switch-all
    boot-host
  ];
}
