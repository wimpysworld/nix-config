{
  config,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
in
{
  programs = {
    gpg = {
      enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package =
        if host.is.linux && host.is.workstation then pkgs.pinentry-gnome3 else pkgs.pinentry-curses;
    };
  };
}
