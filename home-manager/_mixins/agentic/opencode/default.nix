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
  inherit (pkgs.stdenv.hostPlatform) system;
  defaultOpenCodeEnabled = !host.is.server;
  fencedEnabled = !host.is.server;
  aiSopsFile = ../../../../secrets/ai.yaml;
  gatewayEnabled = !noughtyLib.hostHasTag "cg";
  workModelsOnly = noughtyLib.hostHasTag "cg";
  herdrIntegrations = pkgs.herdr-integrations;
  trustedProjectConfigRoots = [
    "${config.home.homeDirectory}/Chainguard"
    "${config.home.homeDirectory}/Development"
    "${config.home.homeDirectory}/Volatile"
    "${config.home.homeDirectory}/Zero"
  ];
  trustedProjectConfigPatterns = lib.concatMapStringsSep " | " (
    root: "${lib.escapeShellArg root} | ${lib.escapeShellArg root}/*"
  ) trustedProjectConfigRoots;
  robotEmoji = builtins.fromJSON "\"\\ud83e\\udd16\"";
  opencodeUpstreamPackage = inputs.llm-agents.packages.${system}.opencode2;
  providerRouterMap = pkgs.writeText "opencode-provider-routes.json" (
    builtins.toJSON config.agentic.assistants.opencode.providerRouterMap
  );
  providerRouterVariantMap = pkgs.writeText "opencode-provider-variants.json" (
    builtins.toJSON config.agentic.assistants.opencode.providerRouterVariantMap
  );
  providerRouterPlugin =
    builtins.replaceStrings
      [ "@routerModule@" "@routerMap@" "@routerVariants@" ]
      [ "${./provider-router/index.mjs}" "${providerRouterMap}" "${providerRouterVariantMap}" ]
      (builtins.readFile ./plugins/provider-router.ts);
  geminiKeyPath = config.sops.secrets.GEMINI_API_KEY.path;
  opencodeApiKeyShell = ''
    if [ -r "${geminiKeyPath}" ]; then
      GEMINI_API_KEY="$(cat "${geminiKeyPath}")"
      export GEMINI_API_KEY
      GOOGLE_GENERATIVE_AI_API_KEY="$GEMINI_API_KEY"
      export GOOGLE_GENERATIVE_AI_API_KEY
    fi
  ''
  + lib.optionalString config.agentic.personalComputer ''
    if [ -r "${config.sops.secrets.ANTHROPIC_API_KEY.path}" ]; then
      ANTHROPIC_API_KEY="$(cat "${config.sops.secrets.ANTHROPIC_API_KEY.path}")"
      export ANTHROPIC_API_KEY
    fi
  ''
  + lib.optionalString gatewayEnabled ''
    if [ -r "${config.sops.secrets.OPENCODE_API_KEY.path}" ]; then
      OPENCODE_API_KEY="$(cat "${config.sops.secrets.OPENCODE_API_KEY.path}")"
      export OPENCODE_API_KEY
    fi
  '';
  communicationRules = config.agentic.communicationRules;
  opencodeTripwireCorrectionPromptFile = pkgs.writeTextFile {
    name = "opencode-communication-rules-correction-prompt.md";
    text = communicationRules.correctionPrompt;
  };
  opencodeTripwirePlugin =
    if communicationRules.mkPluginAdapter == null then
      null
    else
      communicationRules.mkPluginAdapter {
        agent = "opencode";
        shim = ./plugins/communication-rules.ts;
        correctionPrompt = opencodeTripwireCorrectionPromptFile;
        substitutions = {
          "@tripwireScanner@" = communicationRules.executable;
          "@tripwireRules@" = communicationRules.rulesPath;
          "@tripwireCorrectionPrompt@" = "${opencodeTripwireCorrectionPromptFile}";
        };
      };
  opencodePackage = pkgs.symlinkJoin {
    name = "opencode-wrapped-${opencodeUpstreamPackage.version or "unknown"}";
    paths = [ opencodeUpstreamPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode2 \
        --run ${lib.escapeShellArg opencodeApiKeyShell}
    '';
    inherit (opencodeUpstreamPackage) meta;
    passthru.unwrapped = opencodeUpstreamPackage;
  };
  cliSettings = import ./cli.nix {
    inherit lib host;
    flavour = config.catppuccin.opencode.flavor;
  };
  opencodeLauncherPackage = pkgs.writeShellApplication {
    name = "opencode";
    text =
      builtins.replaceStrings
        [ "@trustedRoots@" "@opencode@" ]
        [ trustedProjectConfigPatterns (lib.getExe' opencodePackage "opencode2") ]
        (builtins.readFile ./launcher.sh);
    passthru.unwrapped = opencodeUpstreamPackage;
    derivationArgs.postCheck = ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.cache"
      mkdir -p "$HOME"
      export PATH="${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.python3
        ]
      }:$PATH"
      export OPENCODE_TEST_BINARY=${lib.getExe' opencodeUpstreamPackage "opencode2"}
      export OPENCODE_TEST_DELIVERY=${
        pkgs.writeText "opencode-test-delivery.json" (
          builtins.toJSON {
            files =
              lib.mapAttrsToList
                (_: file: {
                  inherit (file) target source recursive;
                })
                (
                  lib.filterAttrs (
                    _: file:
                    lib.hasPrefix "${config.xdg.configHome}/opencode/plugins/" "${config.home.homeDirectory}/${file.target}"
                    ||
                      "${config.home.homeDirectory}/${file.target}"
                      == "${config.xdg.configHome}/opencode/agents/donatello.md"
                  ) config.home.file
                );
            inherit (config.programs.opencode.settings) permissions;
          }
        )
      }
      ${lib.getExe pkgs.bun} test ${./.}/provider-router/index.test.mjs ${./.}/plugins/communication-rules.test.ts ${./.}/launcher.test.ts
    '';
  };
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceAgentShare = import ../fence/agent-share.nix { inherit config pkgs; };
  fenceGit = import ../fence/git.nix { inherit config pkgs; };
  fenceWaylandBridge = import ../fence/wayland-bridge.nix { inherit pkgs; };
  fenceMemoryCap = import ../fence/memory-cap.nix { inherit lib pkgs; };
  fenceChromium =
    if !(host.is.linux && fencedEnabled) then
      {
        runtimeInputs = [ ];
        setupShell = "";
      }
    else
      import ../fence/chromium.nix { inherit pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };
  opencodeFencedPackage = pkgs.writeShellApplication {
    name = "opencode-fenced";
    runtimeInputs = [
      fencePackage
    ]
    ++ fenceAgentShare.runtimeInputs
    ++ fenceWaylandBridge.runtimeInputs
    ++ fenceChromium.runtimeInputs
    ++ fenceLogging.runtimeInputs;
    text = ''
      ${opencodeApiKeyShell}
      export HERDR_AGENT=opencode
      if [[ "''${FENCE_SANDBOX:-0}" == 1 ]]; then
        exec ${lib.getExe opencodeLauncherPackage} "$@"
      fi
      ${fenceAgentShare.captureShell}
      ${fenceMemoryCap.captureShell}
      ${fenceWaylandBridge.setupShell}
      ${fenceAgentShare.setupShell}
      ${fenceGit.setupShell}
      ${fenceChromium.setupShell}
      fence_log_agent="opencode"
      ${fenceLogging.setupShell}
      ${fenceMemoryCap.setupShell}
      "''${fence_launch[@]}" fence "''${fence_args[@]}" -- "''${fence_env[@]}" "''${fence_direnv[@]}" ${lib.getExe opencodeLauncherPackage} "$@"
    '';
  };
in
{
  sops.secrets.GEMINI_API_KEY = lib.mkIf config.programs.opencode.enable {
    sopsFile = aiSopsFile;
    mode = "0400";
  };
  sops.secrets.OPENCODE_API_KEY = lib.mkIf (config.programs.opencode.enable && gatewayEnabled) {
    sopsFile = aiSopsFile;
    mode = "0400";
  };
  catppuccin.opencode.enable = lib.mkForce false;
  home.packages = lib.optional (
    config.programs.opencode.enable && fencedEnabled
  ) opencodeFencedPackage;
  xdg.configFile = lib.mkMerge [
    (lib.mkIf config.programs.opencode.enable {
      "opencode/plugins/provider-router".source = pkgs.writeTextFile {
        name = "opencode-provider-router";
        destination = "/index.ts";
        text = providerRouterPlugin;
      };
      "opencode/cli.json".text = builtins.toJSON cliSettings;
    })
    (lib.mkIf (config.programs.opencode.enable && communicationRules.enable) {
      "opencode/plugins/communication-rules".source = pkgs.writeTextFile {
        name = "opencode-communication-rules";
        destination = "/index.ts";
        text = opencodeTripwirePlugin.pluginText;
      };
    })
    (lib.mkIf (config.programs.opencode.enable && host.is.linux) {
      "opencode/herdr-tui-session.js".source =
        "${herdrIntegrations}/home/.config/opencode/herdr-tui-session.js";
      "opencode/herdr-opencode/tui.js".source =
        "${herdrIntegrations}/home/.config/opencode/herdr-opencode/tui.js";
    })
  ];
  assertions = [
    {
      assertion = herdrIntegrations.version == pkgs.herdr.version;
      message = "The OpenCode Herdr integrations must match Herdr ${pkgs.herdr.version}.";
    }
  ];
  programs = {
    bash.shellAliases = lib.mkIf (config.programs.opencode.enable && fencedEnabled) {
      opencode-fenced = lib.getExe opencodeFencedPackage;
    };
    fish.shellAliases = lib.mkIf (config.programs.opencode.enable && fencedEnabled) {
      opencode-fenced = lib.getExe opencodeFencedPackage;
    };
    zsh.shellAliases = lib.mkIf (config.programs.opencode.enable && fencedEnabled) {
      opencode-fenced = lib.getExe opencodeFencedPackage;
    };
    opencode = lib.mkMerge [
      { enable = lib.mkDefault defaultOpenCodeEnabled; }
      (lib.mkIf config.programs.opencode.enable {
        package = opencodeLauncherPackage;
        settings = {
          update = "disable";
          share = "disabled";
          websearch = false;
          permissions = [
            {
              action = "external_directory";
              resource = "*";
              effect = "ask";
            }
            {
              action = "webfetch";
              resource = "*";
              effect = "deny";
            }
            {
              action = "websearch";
              resource = "*";
              effect = "deny";
            }
          ];
          model = if workModelsOnly then "google/gemini-4-argon" else "opencode-go/glm-5.3-flash";
          # V2 has no small_model field. Its legacy migration moves small_model
          # to the built-in title agent, so set that agent's model directly.
          agents = lib.mkIf workModelsOnly { title.model = "google/gemini-3.8-flash"; };
          # V2 replaces disabled_providers with provider.use deny policies.
          policies = lib.mkIf workModelsOnly (
            map
              (provider: {
                action = "provider.use";
                resource = provider;
                effect = "deny";
              })
              [
                "opencode"
                "opencode-go"
              ]
          );
          providers = {
            opencode = lib.mkIf gatewayEnabled { settings.apiKey = "{env:OPENCODE_API_KEY}"; };
            opencode-go = lib.mkIf gatewayEnabled { settings.apiKey = "{env:OPENCODE_API_KEY}"; };
            openai.models =
              lib.genAttrs
                [
                  "gpt-5.6-sol"
                  "gpt-5.6-terra"
                  "gpt-5.6-luna"
                  "gpt-6-astra"
                  "gpt-6-luna"
                  "gpt-6.1-sol"
                ]
                (_: {
                  limit = {
                    context = 384000;
                    output = 38400;
                  };
                });
          };
          # V2 uses the resolved input limit, then its default reserve. Keep the
          # model limits without imposing a new buffer on unrelated providers.
          compaction.auto = true;
          commands.init = {
            description = "Create AGENTS.md ${robotEmoji}";
            agent = "rosey";
            template = builtins.readFile ../assistants/commands/create-agents-md/command.md;
          };
        };
      })
    ];
  };
}
