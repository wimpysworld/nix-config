# This is not currently referenced, home-manager is used instead
{ desktop, lib, pkgs, username, ... }:
let
  isWorkstation = if (desktop != null) then true else false;
in
lib.mkIf (username == "martin") {
  environment.systemPackages = with pkgs; [
  ] ++ lib.optionals (isWorkstation) [
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
