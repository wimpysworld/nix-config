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
  environment.systemPackages = with pkgs; [
    gnome.dconf-editor
    pika-backup
    usbimager
  ];

  programs = {
    dconf.profiles.user.databases = [
      {
        settings = with lib.gvariant; {
          "ca/desrt/dconf-editor" = {
            show-warning = false;
          };
        };
      }
    ];
  };
}
