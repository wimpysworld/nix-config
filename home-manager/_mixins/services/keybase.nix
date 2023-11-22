{ desktop, lib, ... }: {
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
