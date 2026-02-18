{
  lib,
  noughtyLib,
  ...
}:
lib.mkIf
  (noughtyLib.isHost [
    "vader"
    "phasma"
  ])
  {
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
