{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  isMartin = noughtyLib.isUser [ "martin" ];
  moltisEnabled = isMartin && host.is.linux && noughtyLib.hostHasTag "moltis";

  username = config.noughty.user.name;
  homeDir = config.home.homeDirectory;

  hermesSopsFile = ../../../../secrets/hermes.yaml;
  aiSopsFile = ../../../../secrets/ai.yaml;
  mcpSopsFile = ../../../../secrets/mcp.yaml;
  linearSopsFile = ../../../../secrets/linear.yaml;
  # Same work-host split that `mcp/default.nix` uses for `LINEAR_API_KEY`:
  # one `key` attribute per identity in the same sops file.
  isWorkHost = lib.elem "cg" (host.tags or [ ]);

  # Environment variables the composed `moltis.toml` references, mapped to
  # the sops file each one comes from. Mirrors the NixOS-side declarations in
  # `nixos/_mixins/server/hermes/default.nix`; Home Manager and NixOS keep
  # separate `sops.secrets` module systems, so the shared key names coexist.
  moltisSecretSopsFiles = {
    TELEGRAM_BOT_TOKEN = hermesSopsFile;
    TELEGRAM_ALLOWED_USERS = hermesSopsFile;
    OPENCODE_ZEN_API_KEY = aiSopsFile;
    CONTEXT7_API_KEY = mcpSopsFile;
    LINEAR_API_KEY = linearSopsFile;
  };

  secretConfig =
    name:
    if name == "LINEAR_API_KEY" then
      {
        sopsFile = linearSopsFile;
        key = if isWorkHost then "chainguard" else "wimpysworld";
      }
    else
      { sopsFile = moltisSecretSopsFiles.${name}; };

  # Plumbing for the composed `moltis.toml`: one entry per environment
  # variable, with its sops source and ready-made placeholder.
  # `OPENCODE_GO_API_KEY` has no sops key of its own; its value is the
  # `OPENCODE_ZEN_API_KEY` value, so it is an alias entry.
  moltisEnvPlumbing =
    map (
      name:
      {
        inherit name;
      }
      // {
        sopsFile = moltisSecretSopsFiles.${name};
        placeholder = config.sops.placeholder.${name};
      }
    ) (lib.attrNames moltisSecretSopsFiles)
    ++ [
      {
        name = "OPENCODE_GO_API_KEY";
        aliasOf = "OPENCODE_ZEN_API_KEY";
        placeholder = config.sops.placeholder.OPENCODE_ZEN_API_KEY;
      }
    ];

  # PATH entries for the systemd user unit, mirroring `paseo/default.nix`.
  moltisPath = lib.concatStringsSep ":" [
    "${homeDir}/.nix-profile/bin"
    "${homeDir}/.local/state/nix/profile/bin"
    "/etc/profiles/per-user/${username}/bin"
    "/run/current-system/sw/bin"
    "/run/wrappers/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  # Fence plumbing for the daemon wrapper: only the fence binary and the
  # logging helper. The shared agent-share, wayland-bridge, git, and
  # chromium setups target interactive TUI agents; a headless daemon needs
  # none of direnv capture, Wayland bridging, git setup, or Chromium.
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };

  moltisFencedPackage = pkgs.writeShellApplication {
    name = "moltis-fenced";
    runtimeInputs = [
      fencePackage
    ]
    ++ fenceLogging.runtimeInputs;
    text = ''
      fence_args=()
      fence_env=()

      fence_log_agent="moltis"
      ${fenceLogging.setupShell}

      # The rendered `[env]` table already carries the real secret values at
      # sops render time, so unlike `opencode-fenced` no key-read prologue is
      # needed here. The gateway is a foreground daemon, so `fence -- moltis`
      # satisfies the unit's `Type = "simple"` contract. The `fence_direnv`
      # launcher is inert here: the unit runs at $HOME, away from any
      # project `.envrc`.
      exec fence "''${fence_args[@]}" -- "''${fence_env[@]}" "''${fence_direnv[@]}" ${lib.getExe pkgs.moltis} "$@"
    '';
  };
in
{
  options.agentic.moltis.envPlumbing = lib.mkOption {
    type =
      with lib.types;
      listOf (
        attrsOf (oneOf [
          str
          path
        ])
      );
    readOnly = true;
    internal = true;
    default = moltisEnvPlumbing;
    description = ''
      Environment variables for the composed Moltis configuration, each with
      its sops file and placeholder. The `OPENCODE_GO_API_KEY` entry is an
      alias of `OPENCODE_ZEN_API_KEY` and carries no sops file.
    '';
  };

  options.agentic.moltis.renderedConfig = lib.mkOption {
    type = with lib.types; path;
    readOnly = true;
    description = ''
      Rendered `moltis.toml` for the child service to symlink into the
      writable Moltis config directory. The sops template substitutes the
      placeholder markers at render time, so the path is the only safe
      consumer: the generated file on any store path still holds markers.
    '';
  };

  config = lib.mkIf moltisEnabled (
    let
      # Import the shared MCP server definitions the same way
      # `mcp/default.nix` does; never re-derive the renderer.
      mcpServerDefs = import ../mcp/servers.nix { inherit config pkgs; };

      # The `[env]` table: one entry per plumbing variable, values replaced
      # with the rendered secret at sops template render time. Moltis makes
      # `[env]` variables part of its process environment, so the literal
      # `${NAME}` placeholders in rendered MCP image headers resolve from it
      # (loader second pass treats `[env]` as an overrides map).
      #
      # Alias choice for `OPENCODE_GO_API_KEY`: the plumbing entry duplicates
      # the same sops placeholder string rather than writing
      # `${OPENCODE_ZEN_API_KEY}`. Either form resolves (the loader
      # substitutes `${VAR}` against `[env]` values), but a direct duplicate
      # avoids one expansion hop and works even if `[env]`-to-`[env]`
      # references regress upstream.
      envBlock =
        lib.listToAttrs (
          lib.map (entry: lib.nameValuePair entry.name entry.placeholder) config.agentic.moltis.envPlumbing
        )
        // {
          # Not a sops secret: Hermes ships the channel id as a plain service
          # environment value. Kept as a Nix literal here; WW-274 may inject it
          # from its own environment instead, making this the fallback.
          TELEGRAM_HOME_CHANNEL = "-1003933927882";
        };
    in
    {
      home.packages = [
        pkgs.moltis
        moltisFencedPackage
      ];

      home.shellAliases.moltis-log = "journalctl --user -u moltis.service";

      systemd.user.services.moltis = {
        Unit.Description = "Moltis - secure persistent personal agent server";
        Service = {
          Type = "simple";
          ExecStart = "${moltisFencedPackage}/bin/moltis-fenced";
          # Only PATH. The rendered `[env]` table already holds real secrets
          # at sops render time; moltis resolves `${VAR}` placeholders
          # against the process env first, then `[env]`.
          Environment = [ "PATH=${moltisPath}" ];
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };

      sops.secrets = lib.genAttrs (lib.attrNames moltisSecretSopsFiles) secretConfig;

      agentic.moltis.renderedConfig = config.sops.templates."moltis.toml".path;

      sops.templates."moltis.toml" = {
        content = builtins.readFile (
          (pkgs.formats.toml { }).generate "moltis.toml" {
            # Pin the gateway server address. `ServerConfig::default().port`
            # is 0, and a port of 0 on disk makes `initialize_config()`
            # generate a random port and write it back to the config file it
            # loaded, which against this layout means writing through the
            # sops-rendered symlink on every restart (crates/config/src/
            # schema/system.rs and crates/config/src/loader/config_io.rs,
            # tag 20260913.02). A non-zero port on loopback prevents both.
            server = {
              port = 13131;
              bind = "127.0.0.1";
            };

            # Moltis resolves `${VAR}` placeholders against the process
            # environment, and the config loader's second pass treats the
            # `[env]` table as an overrides map (crates/config/src/loader.rs,
            # tag 20260913.02). Placeholders here come from `envPlumbing`,
            # so no literal secret value ever enters a store path.
            env = envBlock;

            mcp.servers = mcpServerDefs.moltisServers;

            agents = {
              # Hermes lane mapping. `coordinator` carries the delegation
              # lane (`delegation` in the Hermes settings) and is the
              # default spawn preset, mirroring Hermes' delegation-first
              # posture. Auxiliary presets follow Hermes' auxiliary routing:
              # fast/cheap classifier work on the Go relay, long-context
              # summarisation on MiniMax M3 and quality review on GLM 5.3,
              # both on the Zen relay. Every lane runs at medium effort in
              # Hermes today, so each preset pins `reasoning_effort`
              # explicitly. Model ids use Moltis' `provider::model`
              # namespace separator (crates/providers/src/model_id.rs).
              default_preset = "coordinator";
              presets = {
                coordinator = {
                  model = "custom-opencode-go::glm-5.3-flash";
                  reasoning_effort = "medium";
                  delegate_only = true;
                };
                auxiliary = {
                  # Classifier-shaped lanes in Hermes (approval, titles,
                  # monitor): fast and cheap, on the primary relay.
                  model = "custom-opencode-go::glm-5.3-flash";
                  reasoning_effort = "medium";
                };
                compression = {
                  # Long-context summarisation/compression-shaped lanes
                  # (compression, curator): MiniMax M3 on the Zen relay.
                  model = "custom-opencode-zen::minimax-m3";
                  reasoning_effort = "medium";
                };
                review = {
                  # Review-shaped lane: the flagship tier earns its price.
                  model = "custom-opencode-zen::glm-5.3";
                  reasoning_effort = "medium";
                };
              };
            };

            # Custom OpenAI-compatible relays, named after the Hermes
            # provider table (`hermes_cli/auth.py`, hermes-agent tag
            # v2026.9.14): Go gateway base `https://opencode.ai/zen/go/v1`,
            # Zen gateway base `https://opencode.ai/zen/v1`. One Zen API key
            # authenticates both relays, exported as two env vars above.
            # No inline `api_key`: Moltis does not expand `${VAR}` placeholders
            # inside provider `api_key` values, so the credentials must come
            # from the process environment swept in by `[env]`.
            providers = {
              "custom-opencode-go" = {
                enabled = true;
                base_url = "https://opencode.ai/zen/go/v1";
                models = [ "glm-5.3-flash" ];
              };
              "custom-opencode-zen" = {
                enabled = true;
                base_url = "https://opencode.ai/zen/v1";
                models = [
                  "minimax-m3"
                  "glm-5.3"
                ];
              };
            };

            channels = {
              offered = [ "telegram" ];
              telegram.moltis = {
                # BotFather token arrives through `[env]`; Moltis applies
                # `${VAR}` substitution to the whole raw config text, not
                # per-field, so `token` expands at load time
                # (crates/config/src/loader.rs, tag 20260913.02).
                token = "\${TELEGRAM_BOT_TOKEN}";
                dm_policy = "allowlist";
                # Whole-file substitution also covers array elements, so
                # the allowlist can reference a secret env var. One value,
                # exactly one username or user id: upstream does not split
                # comma-joined values here.
                allowlist = [ "\${TELEGRAM_ALLOWED_USERS}" ];
                group_policy = "allowlist";
                # Whole-file substitution resolves this from `[env]`, so the
                # channel id lives exactly once (loader second pass,
                # crates/config/src/loader/config_io.rs, tag 20260913.02).
                group_allowlist = [ "\${TELEGRAM_HOME_CHANNEL}" ];
                # Channel-level model defaults mirror Hermes' `model.default`
                # and `model.provider` (NixOS Hermes module): glm-5.3-flash
                # on the Go relay steers chat sessions.
                model = "glm-5.3-flash";
                model_provider = "custom-opencode-go";
              };
            };
          }
        );
        path = "${config.xdg.configHome}/moltis/moltis.toml";
      };
    }
  );
}
