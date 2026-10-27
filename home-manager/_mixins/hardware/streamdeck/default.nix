{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  username = config.noughty.user.name;
  hasStreamdeck = noughtyLib.hostHasTag "streamdeck";
  sessionTarget = config.wayland.systemd.target;
  # Bundle all .deck config files into a single store directory so that
  # relative deck references (deck = "foo.deck") resolve correctly.
  deckmaster-xl-config = pkgs.runCommand "deckmaster-xl-config" { } ''
    mkdir -p $out
    cp ${./xl}/*.deck $out/
  '';
in
lib.mkIf (host.is.linux && !host.is.server) {
  home.packages = with pkgs; [ deckmaster ];

  # Systemd user service for deckmaster on stream workstations
  systemd.user.services.deckmaster-xl = lib.mkIf (hasStreamdeck && sessionTarget != "") {
    Unit = {
      Description = "Deckmaster XL for Stream Deck";
      After = [ sessionTarget ];
      PartOf = [ sessionTarget ];
      # Restart up to 5 times within 60 seconds before giving up
      StartLimitBurst = 5;
      StartLimitIntervalSec = 60;
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.deckmaster}/bin/deckmaster -deck ${deckmaster-xl-config}/main.deck";
      Restart = "on-failure";
      RestartSec = "5s";
      # Inherit full system PATH so deckmaster can execute shell scripts and system binaries
      Environment = [
        "PATH=/run/wrappers/bin:/home/${username}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
      ];
    };

    Install = {
      WantedBy = [ sessionTarget ];
    };
  };
}
