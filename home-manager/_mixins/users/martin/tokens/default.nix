{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  enabled =
    noughtyLib.isUser [ "martin" ]
    && noughtyLib.userHasTag "developer"
    && noughtyLib.hostHasTag "policy";

  googleCloudSdk = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components; [ beta ]
  );

  productionAudiences = [
    "https://console-api.enforce.dev"
    "apk.cgr.dev"
    "cgr.dev"
    "libraries.cgr.dev"
  ];
  mcpAudiences = [
    "https://apk.cgr.dev/mcp"
    "https://cgr.dev/mcp"
    "https://versions.cgr.dev/mcp"
    "https://build-mcp.enforce.dev/mcp"
    "https://agent-trace-mcp.enforce.dev/mcp"
  ];
  stageEnvironment = "chainops.dev";
  stageMcpAudiences = [ "https://agent-trace-mcp.${stageEnvironment}/mcp" ];
  stageAudiences = [ "https://console-api.${stageEnvironment}" ] ++ stageMcpAudiences;

  flagsFor = audiences: lib.concatMapStringsSep " " (audience: "--audience=${audience}") audiences;
  productionFlags = flagsFor (productionAudiences ++ mcpAudiences);
  stageFlags = flagsFor stageAudiences;
  mcpFlags = flagsFor (mcpAudiences ++ stageMcpAudiences);

  mkEnvironmentConfig =
    environment:
    pkgs.writeText "chainctl-${environment}.yaml" ''
      default:
          social-login: google-oauth2
          use-refresh-token: true
      platform:
          api: https://console-api.${environment}
          audience: https://console-api.${environment}
          console: https://console.${environment}
          issuer: https://issuer.${environment}
    '';
  stageConfigFile = mkEnvironmentConfig stageEnvironment;
  stageConfig = "${config.xdg.configHome}/chainctl/stage-${stageEnvironment}.yaml";

  mcpTokens = pkgs.writeShellApplication {
    name = "mcp-tokens-private";
    runtimeInputs = [
      pkgs.chainctl
      pkgs.python3
    ];
    text = ''
      export CHAINGUARD_DEFAULT_SKIP_AUTO_LOGIN=true
      exec python3 "${./mcp-tokens.py}" ${mcpFlags} "$@"
    '';
  };

  mintTokens = pkgs.writeShellApplication {
    name = "mint-tokens";
    runtimeInputs = [
      pkgs.chainctl
      pkgs.coreutils
      googleCloudSdk
      pkgs.gnugrep
    ];
    text = ''
      export MINT_PROD_AUDIENCES=${
        lib.escapeShellArg (lib.concatStringsSep " " (productionAudiences ++ mcpAudiences))
      }
      export MINT_STAGE_AUDIENCES=${lib.escapeShellArg (lib.concatStringsSep " " stageAudiences)}
      export MINT_MCP_TOKENS=${lib.escapeShellArg (lib.getExe mcpTokens)}
      export MINT_STAGE_ENV=${lib.escapeShellArg stageEnvironment}
      exec bash "${./mint-tokens.sh}" "$@"
    '';
  };

  productionRefresh = pkgs.writeShellApplication {
    name = "chainctl-auth-refresh-private";
    runtimeInputs = [ pkgs.chainctl ];
    text = ''
      export CHAINGUARD_DEFAULT_SKIP_AUTO_LOGIN=true
      exec chainctl auth login --refresh-only ${productionFlags} </dev/null
    '';
  };
  mkEnvironmentRefresh =
    {
      name,
      configPath,
      configFile,
      audienceFlags,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.chainctl
        pkgs.coreutils
      ];
      text = ''
        install -Dm600 ${configFile} ${configPath}
        export CHAINGUARD_DEFAULT_SKIP_AUTO_LOGIN=true
        exec chainctl --config ${configPath} auth login --refresh-only ${audienceFlags} </dev/null
      '';
    };
  stageRefresh = mkEnvironmentRefresh {
    name = "chainctl-auth-refresh-stage-private";
    configPath = stageConfig;
    configFile = stageConfigFile;
    audienceFlags = stageFlags;
  };
  refreshServices = [
    "chainctl-auth-refresh.service"
    "chainctl-auth-refresh-stage.service"
  ];
  mkRefreshService = description: package: {
    Unit.Description = description;
    Service = {
      Type = "simple";
      ExecStart = lib.getExe package;
      Restart = "always";
      RestartSec = 60;
    };
    Install.WantedBy = [ "default.target" ];
  };
in
lib.mkIf enabled {
  home.packages = [ mintTokens ];

  systemd.user.services = lib.mkIf host.is.linux {
    chainctl-auth-refresh = mkRefreshService "Refresh production chainctl auth tokens" productionRefresh;
    chainctl-auth-refresh-stage = mkRefreshService "Refresh staging chainctl auth tokens" stageRefresh;
    mcp-tokens = {
      Unit = {
        Description = "Copy Chainguard MCP tokens into Claude Code";
        Wants = refreshServices;
        After = refreshServices;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe mcpTokens} --quiet";
      };
    };
  };

  systemd.user.timers.mcp-tokens = lib.mkIf host.is.linux {
    Unit.Description = "Copy Chainguard MCP tokens into Claude Code on a schedule";
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
      RandomizedDelaySec = "5m";
      Unit = "mcp-tokens.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
