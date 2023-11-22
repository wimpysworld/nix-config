{ desktop, lib, ... }: {
  # TODO: Ignore on Darwin
  #imports = [ ] ++ lib.optionals (desktop != null) [
  #  ./keybase-gui.nix
  #];

  services = {
    kbfs = {
      enable = true;
      mountPoint = "Keybase";
    };
  };
}
