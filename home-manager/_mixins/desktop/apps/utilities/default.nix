{
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];
in
lib.mkIf (builtins.elem username installFor) {
  home.packages = with pkgs; [
    cpu-x
    dconf-editor
    pika-backup
    squirreldisk
    usbimager
  ];

  dconf.settings = with lib.hm.gvariant; {
    "ca/desrt/dconf-editor" = {
      show-warning = false;
    };
  };
}
