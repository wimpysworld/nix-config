{ desktop, lib, ... }: {
  imports = [
    ./distrobox.nix
    ./podman.nix
  ]
  ++ lib.optionals (builtins.isString desktop) [
    ./distrobox-desktop.nix
    ./quickemu.nix
  ];
}
