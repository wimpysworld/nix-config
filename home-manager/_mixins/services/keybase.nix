{ desktop, lib, ... }: {
  imports = [ ] ++ lib.optionals (desktop != null) [
    ../desktop/keybase.nix
  ];
  
  services = {
    kbfs = {
      enable = true;
      mountPoint = "Keybase";
    };
  };
}
