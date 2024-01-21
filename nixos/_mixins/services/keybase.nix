{ lib, username, ... }:
lib.mkIf (username == "martin") {
  services = {
    keybase = {
      enable = true;
      kbfs = {
        enable = true;
        enableRedirector = true;
        extraFlags = [ "-mode=minimal" ];
        mountPoint = "%h/Keybase";
      };
    };
  };
}
