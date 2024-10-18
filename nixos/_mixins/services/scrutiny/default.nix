{ hostname, lib, ... }:
let
  installOn = [ "malak" "revan" "phasma" "vader" ];
in
lib.mkIf (lib.elem hostname installOn) {
  services.scrutiny = {
    enable = true;
    collector.enable = true;
    collector.settings.host.id = "${hostname}";
  };
}
