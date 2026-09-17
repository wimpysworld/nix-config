{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;

  isMartin = noughtyLib.isUser [ "martin" ];
  moltisEnabled = isMartin && host.is.linux && noughtyLib.hostHasTag "moltis";

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
      envBlock = lib.listToAttrs (
        lib.map (entry: lib.nameValuePair entry.name entry.placeholder) config.agentic.moltis.envPlumbing
      );
    in
    {
      home.packages = [ pkgs.moltis ];

      sops.secrets = lib.genAttrs (lib.attrNames moltisSecretSopsFiles) secretConfig;

      agentic.moltis.renderedConfig = config.sops.templates."moltis.toml".path;

      sops.templates."moltis.toml" = {
        content = builtins.readFile (
          (pkgs.formats.toml { }).generate "moltis.toml" {
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
                group_allowlist = [ "-1003933927882" ];
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
