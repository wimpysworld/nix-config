{ desktop, lib, ... }: {
  # TODO: Only do this on Linux
  #imports = [ ] ++ lib.optionals (desktop != null) [
  #  ./keybase-gui.nix
  #];
}
