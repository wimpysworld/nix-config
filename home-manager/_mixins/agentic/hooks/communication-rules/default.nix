{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  fragment = import ./fragment.nix { inherit lib; };
  runtimeConfigDir = "${config.xdg.configHome}/agent-communication-rules";
  runtimeRulesPath = "${runtimeConfigDir}/communication-rules.md";
  runtimePolicyPath = "${runtimeConfigDir}/policy.json";
  communicationRulesFile = pkgs.writeTextFile {
    name = "agent-communication-rules.md";
    inherit (fragment) text;
  };
  communicationRulesPolicy = {
    communicationRules = {
      inherit (fragment)
        b1RevisionPrompt
        blockMessage
        correctionPrompt
        detectionPolicy
        reminderPrompt
        text
        ;
    };
  };
  policyFile =
    (pkgs.formats.json { }).generate "agent-communication-rules-policy.json"
      communicationRulesPolicy;
  correctionPromptFile = pkgs.writeTextFile {
    name = "agent-communication-rules-correction-prompt.md";
    text = fragment.correctionPrompt;
  };
  # Ship the scanner entry point alongside the whole core package tree, so the
  # core modules the scanner imports (config, detection, dispatch, state,
  # responses, and the per-agent extractors) are present at runtime. The
  # scanner runs from this directory, so core/ must sit beside it. The tree is
  # copied recursively rather than named file by file, because later tasks add
  # core/extractors/* and naming each file would silently drop new modules.
  coreTree = lib.cleanSourceWith {
    src = ./core;
    filter = path: _type: !(lib.hasSuffix "__pycache__" path);
  };
  scannerFile = pkgs.runCommand "agent-communication-rules-scanner" { } ''
    install -Dm755 ${./scanner.py} "$out/share/agent-communication-rules/scanner.py"
    cp -r ${coreTree} "$out/share/agent-communication-rules/core"
    chmod -R u+w "$out/share/agent-communication-rules/core"
  '';
  scannerPath = "${scannerFile}/share/agent-communication-rules/scanner.py";
  scannerPackage = pkgs.writeShellApplication {
    name = "agent-communication-check";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${lib.escapeShellArg scannerPath} --policy-json ${lib.escapeShellArg policyFile} --rules ${lib.escapeShellArg communicationRulesFile} "$@"
    '';
  };

  # Shared base for the per-agent tripwire adapter helpers. It holds the core
  # package reference, the policy, rules, and default correction-prompt paths,
  # and the environment every agent needs. The base carries no agent identity,
  # event names, or shim: those are parameters to the helpers, so adding a
  # fifth agent never edits the base (acceptance criterion 11).
  tripwireBase = {
    package = scannerPackage;
    executable = lib.getExe scannerPackage;
    inherit policyFile correctionPromptFile;
    rulesFile = communicationRulesFile;
    # Environment the core reads at runtime. The scanner package already bakes
    # --policy-json and --rules, so TRIPWIRE_POLICY_JSON is passed for shims
    # that re-derive paths, and the correction-prompt path is overridable.
    mkEnvExports =
      {
        correctionPrompt ? correctionPromptFile,
      }:
      ''
        export TRIPWIRE_SCANNER="''${TRIPWIRE_SCANNER:-${lib.getExe scannerPackage}}"
        export TRIPWIRE_POLICY_JSON="''${TRIPWIRE_POLICY_JSON:-${policyFile}}"
        export TRIPWIRE_CORRECTION_PROMPT="''${TRIPWIRE_CORRECTION_PROMPT:-${correctionPrompt}}"
      '';
  };

  # Build a command-style hook adapter for an agent whose runtime feeds JSON on
  # stdin to an external command and reads a JSON decision on stdout (Claude
  # Code and Codex). The wrapper exports the shared environment and runs
  # `scanner.py <agent> <event>`; the agent supplies its own event list.
  #
  # Parameters:
  #   agent:           the core agent name, passed verbatim as the first arg.
  #   runtimeInputs:   extra packages on the wrapper PATH.
  #   correctionPrompt: an agent-specific correction-prompt path, optional.
  #   hookEventLabels: an optional event-name to label map. When supplied, the
  #                    returned attrset includes a `trustedHash` builder for
  #                    runtimes that hash the hook identity (Codex). The labels
  #                    come from the caller, so the base stays agent-free.
  mkCommandHookAdapter =
    {
      agent,
      runtimeInputs ? [ ],
      correctionPrompt ? correctionPromptFile,
      hookEventLabels ? { },
    }:
    let
      hookPackage = pkgs.writeShellApplication {
        name = "${agent}-communication-rules-hook";
        runtimeInputs = [
          scannerPackage
          pkgs.coreutils
          pkgs.python3
        ]
        ++ runtimeInputs;
        text = ''
          ${tripwireBase.mkEnvExports { inherit correctionPrompt; }}
          exec ${lib.getExe scannerPackage} ${lib.escapeShellArg agent} "$@"
        '';
      };
    in
    {
      inherit (tripwireBase) package executable;
      inherit hookPackage;
      # Build a single command-hook entry for one event. The shape matches the
      # `type = "command"` hooks both Claude Code and Codex register. The event
      # is folded into the command string rather than carried in a separate
      # `args` list. Codex's command-hook config struct has no `args` field and
      # never passes args to the hook process, and its trust hash is computed
      # over an identity that excludes `args`; an inline `args` therefore made
      # our pre-seeded `trusted_hash` diverge from Codex's, leaving every hook
      # untrusted and triggering the startup "review hooks" prompt on each
      # launch. Both agents run a command-string hook through a shell when no
      # `args` is present, so the trailing event token reaches the wrapper as a
      # positional argument and the wrapper forwards it to `scanner.py <agent>
      # <event>`. Dropping `args` keeps the hashed identity and the written
      # entry byte-identical for Codex while preserving event delivery for both.
      mkHook = event: {
        type = "command";
        command = "${lib.getExe hookPackage} ${lib.escapeShellArg event}";
      };
    }
    // lib.optionalAttrs (hookEventLabels != { }) {
      # Recompute the trusted hash from the hook identity. The caller passes the
      # event labels and the per-event hook group; the helper hashes the same
      # identity JSON the runtime trusts, so a changed command recomputes the
      # hash with no manual step.
      trustedHash =
        eventName: group: hook:
        let
          identity = (lib.optionalAttrs (group ? matcher) { inherit (group) matcher; }) // {
            event_name = hookEventLabels.${eventName};
            hooks = [
              (
                hook
                // {
                  async = hook.async or false;
                  timeout = hook.timeout or 600;
                }
              )
            ];
          };
        in
        "sha256:${builtins.hashString "sha256" (builtins.toJSON identity)}";
    };

  # Build a plugin adapter for an agent whose runtime loads an in-process TS
  # plugin and cannot call an external command (Pi and OpenCode). The helper
  # renders the shim text, substituting the core path and config tokens, and
  # writes the agent's correction prompt. The agent registers the returned
  # `pluginText` in its own config tree.
  #
  # Parameters:
  #   agent:           the core agent name, passed verbatim by the shim's spawn.
  #   shim:            path to the TS shim source file.
  #   substitutions:   token to value map applied to the shim text. Pass an
  #                    empty set to copy the shim verbatim (the agent then holds
  #                    paths in a separate config file).
  #   correctionPrompt: an agent-specific correction-prompt path, optional.
  mkPluginAdapter =
    {
      agent,
      shim,
      substitutions ? { },
      correctionPrompt ? correctionPromptFile,
    }:
    let
      tokens = lib.attrNames substitutions;
      values = lib.attrValues substitutions;
      shimText = builtins.readFile shim;
      pluginText =
        if substitutions == { } then shimText else builtins.replaceStrings tokens values shimText;
    in
    {
      inherit (tripwireBase) package executable;
      inherit agent pluginText correctionPrompt;
    };
in
{
  options.agentic.communicationRules = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      internal = true;
      description = "Whether the generated Communication Rules source is available for agentic modules.";
    };

    text = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Generated Communication Rules fragment body.";
    };

    section = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Generated Communication Rules section with heading.";
    };

    reminderPrompt = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Reminder prompt that embeds the generated Communication Rules fragment.";
    };

    blockMessage = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Block message that embeds the generated Communication Rules fragment.";
    };

    correctionPrompt = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Correction prompt that embeds the generated Communication Rules fragment.";
    };

    detectionPolicy = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      description = "Deterministic scanner policy data derived from the Communication Rules.";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      internal = true;
      description = "Package that provides the stable Communication Rules scanner executable.";
    };

    executable = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Stable Communication Rules scanner executable path.";
    };

    scannerPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Nix store path to the packaged Communication Rules scanner source.";
    };

    rulesPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Runtime path to the generated Communication Rules fragment.";
    };

    policyPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Runtime path to the generated Communication Rules policy data.";
    };

    policyFilePath = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Nix store path to the generated Communication Rules policy JSON, for adapter consumption.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Runtime directory for generated Communication Rules assets.";
    };

    mkCommandHookAdapter = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.attrs);
      default = null;
      internal = true;
      description = "Helper that builds a command-style hook adapter for Claude Code and Codex.";
    };

    mkPluginAdapter = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.attrs);
      default = null;
      internal = true;
      description = "Helper that builds an in-process plugin adapter for Pi and OpenCode.";
    };
  };

  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    agentic.communicationRules = {
      enable = true;
      package = scannerPackage;
      executable = lib.getExe scannerPackage;
      inherit scannerPath;
      configDir = runtimeConfigDir;
      rulesPath = runtimeRulesPath;
      policyPath = runtimePolicyPath;
      policyFilePath = "${policyFile}";
      inherit mkCommandHookAdapter mkPluginAdapter;
      inherit (fragment)
        blockMessage
        correctionPrompt
        detectionPolicy
        reminderPrompt
        section
        text
        ;
    };

    home.packages = [
      scannerPackage
    ];

    xdg.configFile = {
      "agent-communication-rules/communication-rules.md".source = communicationRulesFile;
      "agent-communication-rules/policy.json".source = policyFile;
      "agent-communication-rules/scanner.py".source = scannerPath;
    };
  };
}
