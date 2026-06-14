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
  scannerFile = pkgs.writeTextFile {
    name = "agent-communication-rules-scanner";
    destination = "/share/agent-communication-rules/scanner.py";
    executable = true;
    text = builtins.readFile ./scanner.py;
  };
  scannerPath = "${scannerFile}/share/agent-communication-rules/scanner.py";
  adapterContractFile = pkgs.writeTextFile {
    name = "agent-communication-rules-adapter-contract";
    destination = "/share/agent-communication-rules/adapters/contract.sh";
    text = builtins.readFile ./adapters/contract.sh;
  };
  adapterContractPath = "${adapterContractFile}/share/agent-communication-rules/adapters/contract.sh";
  scannerPackage = pkgs.writeShellApplication {
    name = "agent-communication-check";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${lib.escapeShellArg scannerPath} --policy-json ${lib.escapeShellArg policyFile} --rules ${lib.escapeShellArg communicationRulesFile} "$@"
    '';
  };
  adapterPackage = pkgs.writeShellApplication {
    name = "agent-communication-adapter";
    runtimeInputs = [
      scannerPackage
      pkgs.coreutils
    ];
    text = ''
      export TRIPWIRE_SCANNER="''${TRIPWIRE_SCANNER:-${lib.getExe scannerPackage}}"
      export TRIPWIRE_CORRECTION_PROMPT="''${TRIPWIRE_CORRECTION_PROMPT:-${correctionPromptFile}}"
      # shellcheck source=/dev/null
      source ${lib.escapeShellArg adapterContractPath}
      tripwire_adapter_main "$@"
    '';
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

    adapterPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      internal = true;
      description = "Package that provides the shared Communication Rules adapter helper executable.";
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

    adapterContractPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "Nix store path to the shared adapter shell contract.";
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

    adapterPaths = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      internal = true;
      description = "Runtime adapter executable paths exposed for agent hook modules.";
    };
  };

  config = lib.mkIf (noughtyLib.userHasTag "developer") {
    agentic.communicationRules = {
      enable = true;
      package = scannerPackage;
      inherit adapterPackage;
      executable = lib.getExe scannerPackage;
      inherit adapterContractPath;
      inherit scannerPath;
      configDir = runtimeConfigDir;
      rulesPath = runtimeRulesPath;
      policyPath = runtimePolicyPath;
      policyFilePath = "${policyFile}";
      adapterPaths = {
        contract = adapterContractPath;
        helper = lib.getExe adapterPackage;
      };
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
      adapterPackage
      scannerPackage
    ];

    xdg.configFile = {
      "agent-communication-rules/communication-rules.md".source = communicationRulesFile;
      "agent-communication-rules/policy.json".source = policyFile;
      "agent-communication-rules/scanner.py".source = scannerPath;
    };
  };
}
