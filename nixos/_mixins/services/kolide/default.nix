# https://github.com/kolide/nix-agent
# https://github.com/kolide/nix-agent/blob/main/modules/kolide-launcher/default.nix
{ config, hostname, inputs, lib, ... }:
let
  installOn = [ "maul" ];
in
lib.mkIf (lib.elem hostname installOn) {

  environment.systemPackages = [
    inputs.kolide-launcher
  ];

  services.kolide-launcher = {
    enable = true;
    # The hostname for the Kolide device management server.
    #kolideHostname = "k2device.kolide.com";

    # The path to the directory that will hold launcher-related data, including logs, databases, and autoupdates.
    #rootDirectory = "/var/kolide-k2/k2device.kolide.com";

    # Which release channel the launcher installation should use when autoupdating
    # itself and its osquery installation: one of stable, nightly, beta, or alpha.
    #updateChannel = "stable";

    # The path to the directory where the enrollment secret lives.
    #enrollSecretDirectory = "/etc/kolide-k2";
  };

  sops = {
    secrets = {
      kolide = {
        mode = "0600";
        path = "/etc/kolide-k2/secret";
        sopsFile = ../../../../secrets/kolide.yaml;
      };
    };
  };
}
