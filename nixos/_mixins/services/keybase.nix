# This is not currently referenced, home-manager is used instead
{ desktop, lib, pkgs, username, ... }:
lib.mkIf (username == "martin") {
  environment.systemPackages = with pkgs; [
  ] ++ lib.optionals (desktop != null) [
    keybase-gui
  ];
  services = {
    keybase = {
      enable = true;
    };
    kbfs = {
      enable = true;
      extraFlags = [ "-mode=minimal" ];
      mountPoint = "%h/Keybase";
    };
  };
}
