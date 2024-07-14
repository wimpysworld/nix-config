{
  pkgs,
  ...
}:
let
  switch-all = import ./switch-all.nix { inherit pkgs; };
  boot-host = import ./boot-host.nix { inherit pkgs; };
in
{
  environment.systemPackages = [
    switch-all
    boot-host
  ];
}
