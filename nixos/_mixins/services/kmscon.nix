{ hostname, lib, pkgs, ... }:
let
  # Do not enable kmscon on ISO images
  isISO = builtins.substring 0 4 hostname == "iso-";
in
lib.mkIf (!isISO) {
  services = {
    kmscon = {
      enable = true;
      hwRender = true;
      fonts = [{
        name = "FiraCode Nerd Font Mono";
        package = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
      }];
      extraConfig = ''
        font-size=14
        xkb-layout=gb
      '';
    };
  };
}
