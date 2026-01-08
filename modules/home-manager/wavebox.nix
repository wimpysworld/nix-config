# Wavebox browser Home Manager module
# Based on NixOS's programs.chromium module for policy-based extension management
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.wavebox;

  # Wavebox config directory varies by platform
  configDir =
    if pkgs.stdenv.isDarwin then
      "Library/Application Support/WaveboxApp"
    else
      "${config.xdg.configHome}/wavebox";

  # Dictionary file linking
  dictionary = pkg: {
    name = "${configDir}/Dictionaries/${pkg.passthru.dictFileName}";
    value.source = pkg;
  };

  # Native messaging hosts symlink join
  nativeMessagingHostsJoined = pkgs.symlinkJoin {
    name = "wavebox-native-messaging-hosts";
    paths = cfg.nativeMessagingHosts;
  };
in
{
  options.programs.wavebox = {
    enable = mkEnableOption "Wavebox browser";

    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.wavebox or null;
      defaultText = literalExpression "pkgs.wavebox";
      description = "The Wavebox package to use. Set to null to not install the package.";
    };

    finalPackage = mkOption {
      type = types.nullOr types.package;
      readOnly = true;
      description = ''
        Resulting customised Wavebox package.
      '';
    };

    commandLineArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "--enable-logging=stderr"
        "--ignore-gpu-blocklist"
      ];
      description = ''
        List of command-line arguments to be passed to Wavebox.

        For a list of common switches, see
        [Chrome switches](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/common/chrome_switches.cc).
      '';
    };

    dictionaries = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression ''
        [
          pkgs.hunspellDictsChromium.en_US
        ]
      '';
      description = ''
        List of Wavebox dictionaries to install.
      '';
    };

    nativeMessagingHosts = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression ''
        [
          pkgs.kdePackages.plasma-browser-integration
        ]
      '';
      description = ''
        List of Wavebox native messaging hosts to install.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.package == null && cfg.commandLineArgs != [ ]);
        message = "Cannot set `commandLineArgs` when `package` is null for wavebox.";
      }
    ];

    programs.wavebox.finalPackage =
      if cfg.package == null then
        null
      else if cfg.commandLineArgs != [ ] then
        cfg.package.override { commandLineArgs = lib.concatStringsSep " " cfg.commandLineArgs; }
      else
        cfg.package;

    home.packages = lib.mkIf (cfg.finalPackage != null) [
      cfg.finalPackage
    ];

    home.file = lib.listToAttrs (map dictionary cfg.dictionaries) // {
      "${configDir}/NativeMessagingHosts" = lib.mkIf (cfg.nativeMessagingHosts != [ ]) {
        source = "${nativeMessagingHostsJoined}/etc/chromium/native-messaging-hosts";
        recursive = true;
      };
    };
  };
}
