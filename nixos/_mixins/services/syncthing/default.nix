{ desktop, lib, ...}:
{
  imports = [
    ./syncthing.nix
  ] ++ lib.optional (builtins.isString desktop) ./syncthing-tray.nix;
}
