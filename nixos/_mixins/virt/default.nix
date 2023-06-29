{ desktop, lib, ... }: {
  imports = [
    ./distrobox.nix
    ./podman.nix
  ]
  ++ lib.optional (builtins.isString desktop) ./quickemu.nix;
}
