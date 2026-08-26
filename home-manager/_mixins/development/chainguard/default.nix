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
  # The MCP resource URLs sit in mcpAudiences below, and audienceFlags joins the
  # two lists.
  audiences = [
    "https://console-api.enforce.dev"
    "apk.cgr.dev"
    "cgr.dev"
    "libraries.cgr.dev"
  ];
  # The MCP servers Claude Code talks to. They are kept apart from the list
  # above because they are resource URLs, not hostnames: those servers follow
  # RFC 8707 resource indicators and reject a token whose audience is anything
  # but the exact URL from their .well-known/oauth-protected-resource document.
  #
  # cg-tokens and chainctl-auth-refresh cover both lists, because audienceFlags
  # below joins them.
  mcpAudiences = [
    "https://apk.cgr.dev/mcp"
    "https://cgr.dev/mcp"
    "https://versions.cgr.dev/mcp"
    "https://build-mcp.enforce.dev/mcp"
    "https://agent-trace-mcp.enforce.dev/mcp"
  ];
  # The staging MCP server accepts only tokens from the staging issuer, so its
  # login cannot join the list above. cg-tokens runs it as a second login in the
  # same command, so one login covers both environments.
  #
  # Only the login needs the separate environment. Minting needs nothing extra,
  # because chainctl keys its token cache by audience and holds the issuer that
  # signed each entry, so `chainctl auth token` returns a staging token through
  # the shared config.
  stageEnv = "chainops.dev";
  stageMcpAudiences = [ "https://agent-trace-mcp.${stageEnv}/mcp" ];
  # The platform audience joins the staging login so that the login leaves a
  # usable staging session behind, not one that holds MCP tokens alone.
  stageAudiences = [ "https://console-api.${stageEnv}" ] ++ stageMcpAudiences;
  stageAudienceFlags = lib.concatMapStringsSep " " (
    audience: "--audience=${audience}"
  ) stageAudiences;
  stageConfig = "${config.xdg.configHome}/chainctl/stage-${stageEnv}.yaml";
  # chainctl persists --api and --issuer into the platform.* block of whichever
  # config file it uses, so a staging login against the shared config would
  # repoint every later production login at the staging issuer. This config file
  # of its own prevents that, exactly as bot-tokens does for a dev env.
  #
  # chainctl fails on a missing config file rather than creating one, so it is
  # installed from the store. Overwriting it on every run is safe: nothing else
  # writes it, and the only state chainctl adds is auth.mode, which cg-tokens
  # passes on the command line instead.
  stageConfigFile = pkgs.writeText "chainctl-stage-${stageEnv}.yaml" ''
    default:
        social-login: google-oauth2
        use-refresh-token: true
    platform:
        api: https://console-api.${stageEnv}
        audience: https://console-api.${stageEnv}
        console: https://console.${stageEnv}
        issuer: https://issuer.${stageEnv}
  '';
  audienceFlags = lib.concatMapStringsSep " " (audience: "--audience=${audience}") (
    audiences ++ mcpAudiences
  );
  # mcp-tokens needs every MCP audience, and it makes no distinction between the
  # environments: chainctl resolves the issuer from its cache, so minting a
  # staging audience takes the same command as a production one.
  mcpAudienceFlags = lib.concatMapStringsSep " " (audience: "--audience=${audience}") (
    mcpAudiences ++ stageMcpAudiences
  );
  # cg-tokens mints the MCP tokens and chainctl-auth-refresh renews them, but
  # both write to the chainctl cache and Claude Code never reads that cache.
  # mcp-tokens is the copy step between the cache and Claude Code's credential
  # store, and the timer below runs it. It stays a separate executable from
  # cg-tokens because chainctl-auth-refresh renews a token with no login, and a
  # copy step inside cg-tokens would leave Claude Code with a dead token between
  # one daily login and the next.
  mcpTokens = pkgs.writeShellApplication {
    name = "mcp-tokens";
    runtimeInputs = [
      pkgs.chainctl
      pkgs.python3
    ];
    # The path is interpolated straight into the string rather than passed
    # through lib.escapeShellArg. escapeShellArg coerces a path with toString,
    # which drops the string context, and Nix then warns that the derivation
    # carries no store reference to the script.
    text = ''
      exec python3 "${./mcp-tokens.py}" \
        ${mcpAudienceFlags} \
        "$@"
    '';
  };
  # These helpers are declared inline instead of under home-manager/_mixins/scripts/
  # because they share the audience list with the refresh service below.
  #
  # chainctl opens a browser unless --headless is passed, and no flag forces the
  # browser, so the interactive helper passes no mode flag and instead clears
  # the sticky auth.mode that a headless login leaves behind.
  #
  # One command, two logins, because a staging login needs its own config file
  # and one chainctl process reads one config. Expect two browser flows, or two
  # device codes with --headless. The staging login runs second, so a failure to
  # reach staging leaves the production session in place.
  mkCgTokens =
    {
      name,
      modeFlags ? [ ],
      preamble ? "",
    }:
    let
      mode = lib.concatStringsSep " " modeFlags;
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.chainctl
        pkgs.coreutils
      ];
      text = ''
        ${preamble}
        chainctl auth login ${mode} ${audienceFlags} "$@"

        install -Dm600 ${stageConfigFile} ${stageConfig}
        exec chainctl --config ${stageConfig} auth login ${mode} ${stageAudienceFlags} "$@"
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
    pkgs.yam # YAML formatter used by Wolfi package definitions
    cgTokens # Login through the browser flow, for a desktop session
    cgTokensHeadless # Login through the device flow, for an SSH session
    mcpTokens # Copy the MCP tokens into Claude Code's credential store
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

  # The service above covers the default environment only, because its audience
  # flags name no staging audience and one chainctl process reads one config.
  # Left to itself the staging refresh token dies, and agent-trace-mcp-stage then
  # fails until the next cg-tokens.
  #
  # The unit stays separate from cg-tokens because cg-tokens performs two logins
  # in sequence, and --refresh-only on the first would daemonise before the
  # second ever ran.
  systemd.user.services.chainctl-auth-refresh-stage = lib.mkIf host.is.linux {
    Unit.Description = "Refresh chainctl auth tokens for the staging environment";

    Service = {
      Type = "simple";
      # systemd does not search $PATH, so the absolute store path is required.
      ExecStartPre = "${pkgs.coreutils}/bin/install -Dm600 ${stageConfigFile} ${stageConfig}";
      ExecStart = "${lib.getExe pkgs.chainctl} --config ${stageConfig} auth login --refresh-only ${stageAudienceFlags}";
      # This matches the service above: upstream leaves the unit dead after a
      # crash, and 60 seconds matches chainctl's own internal retry cadence.
      Restart = "on-failure";
      RestartSec = 60;
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Claude Code re-runs the MCP OAuth flow the moment its token expires, and
  # that flow fails with "invalid client_id" because the cached registration no
  # longer applies. Copying a fresh token in before the old one expires is what
  # stops the flow from running at all, so this timer is the fix rather than a
  # convenience.
  #
  # An MCP audience token lasts one hour, measured from its own iat and exp
  # claims. Thirty minutes plus at most five minutes of jitter leaves 25 minutes
  # of margin, so a run that is skipped once still beats the expiry.
  systemd.user.services.mcp-tokens = lib.mkIf host.is.linux {
    Unit.Description = "Copy Chainguard MCP tokens into Claude Code";

    Service = {
      Type = "oneshot";
      # systemd does not search $PATH, so the absolute store path is required.
      # --quiet keeps the journal to changes and faults, because most runs find
      # the store already correct and do nothing.
      ExecStart = "${lib.getExe mcpTokens} --quiet";
    };
  };

  systemd.user.timers.mcp-tokens = lib.mkIf host.is.linux {
    Unit.Description = "Copy Chainguard MCP tokens into Claude Code on a schedule";

    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
      RandomizedDelaySec = "5m";
      Persistent = true;
      Unit = "mcp-tokens.service";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
