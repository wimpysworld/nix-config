{ desktop, lib, pkgs, ... }: {
  imports = [ ] ++ lib.optional (builtins.isString desktop) ../desktop/simple-scan.nix;

  hardware = {
    sane = {
      enable = true;
      #extraBackends = with pkgs; [ hplipWithPlugin sane-airscan ];
      extraBackends = with pkgs; [ sane-airscan ];
    };
  };
}
