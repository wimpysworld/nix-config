{
  hostname,
  lib,
  ...
}:
let
  installOn = [
    "vader"
    "phasma"
  ];
in
lib.mkIf (lib.elem hostname installOn) {
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    relay.enable = true;
    signal.enable = true;
    signal.relayHosts = [
      "vader"
      "phasma"
    ];
  };
}
