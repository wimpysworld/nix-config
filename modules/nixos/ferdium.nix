# Ferdium browser extension management module
# Based on NixOS's programs.chromium module
{ config, lib, ... }:

with lib;

let
  cfg = config.programs.ferdium;

  extensionJson = extensions: {
    ExtensionInstallForcelist = map (
      id: "${id};https://clients2.google.com/service/update2/crx"
    ) extensions;
  };
in
{
  options.programs.ferdium = {
    enable = mkEnableOption "Ferdium policy deployment";

    extensions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of Ferdium extensions to install.
        Extension IDs from the Chrome Web Store.
      '';
      example = literalExpression ''
        [
          "mdkgfdijbhbcbajcdlebbodoppgnmhab" # GoLinks
          "glnpjglilkicbckjpbgcfkogebgllemb" # Okta
        ]
      '';
    };

    extraOpts = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Additional Ferdium policy options.
      '';
      example = literalExpression ''
        {
          "PromptForDownloadLocation" = true;
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.etc."ferdium/policies/managed/extensions.json" = {
      text = builtins.toJSON (extensionJson cfg.extensions // cfg.extraOpts);
    };
  };
}
