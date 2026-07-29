# Chainguard - command-line tools for the Chainguard platform and Wolfi.
{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  isDeveloper = noughtyLib.userHasTag "developer";
  isPolicyHost = noughtyLib.hostHasTag "policy";
  # chainctl issues a separate token per audience. The refresh service and both
  # login helpers have to cover the same set, so the list is defined once here.
  audiences = [
    "https://console-api.enforce.dev"
    "apk.cgr.dev"
    "cgr.dev"
    "libraries.cgr.dev"
  ];
  audienceFlags = lib.concatMapStringsSep " " (audience: "--audience=${audience}") audiences;
  # These helpers are declared inline instead of under home-manager/_mixins/scripts/
  # because they share the audience list with the refresh service below.
  #
  # chainctl opens a browser unless --headless is passed, and no flag forces the
  # browser, so the interactive helper passes no mode flag and instead clears
  # the sticky auth.mode that a headless login leaves behind.
  mkCgTokens =
    {
      name,
      modeFlags ? [ ],
      preamble ? "",
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.chainctl ];
      text = ''
        ${preamble}
        exec chainctl auth login ${lib.concatStringsSep " " (modeFlags ++ [ audienceFlags ])} "$@"
      '';
    };
  cgTokens = mkCgTokens {
    name = "cg-tokens";
    # auth.mode returns to its "browser" default. Unsetting a key that is
    # already at its default exits zero, so this is safe under set -e.
    preamble = "chainctl config unset auth.mode";
  };
  cgTokensHeadless = mkCgTokens {
    name = "cg-tokens-headless";
    modeFlags = [ "--headless" ];
  };
in
lib.mkIf (isDeveloper && isPolicyHost) {
  home.packages = [
    # Also provides docker-credential-cgr, the Docker credential helper for
    # cgr.dev, which chainctl installs by symlinking itself.
    pkgs.chainctl # Command-line interface for the Chainguard platform
    pkgs.wolfictl # Command-line interface for the Wolfi OSS project
    cgTokens # Login through the browser flow, for a desktop session
    cgTokensHeadless # Login through the device flow, for an SSH session
  ];

  # A refresh can only extend a token that still exists, so the user runs
  # cg-tokens, or cg-tokens-headless over SSH, once a day to start a fresh
  # session. Between those logins this service keeps every audience alive:
  # chainctl stays running, sleeps until the shortest-lived token is close to
  # expiring, then refreshes them all. Without it, cgr.dev image pulls and apk
  # fetches start failing part way through the day.
  systemd.user.services.chainctl-auth-refresh = lib.mkIf host.is.linux {
    Unit.Description = "Refresh chainctl auth tokens";

    Service = {
      Type = "simple";
      # systemd does not search $PATH, so the absolute store path is required.
      ExecStart = "${lib.getExe pkgs.chainctl} auth login --refresh-only ${audienceFlags}";
      # This deviates from upstream, which leaves the unit dead after a crash.
      # A 60 second delay matches chainctl's own internal retry cadence.
      Restart = "on-failure";
      RestartSec = 60;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
