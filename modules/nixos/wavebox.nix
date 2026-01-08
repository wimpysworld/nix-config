# Wavebox browser extension management module
# Based on NixOS's programs.chromium module
{ config, lib, ... }:

with lib;

let
  cfg = config.programs.wavebox;

  extensionJson = extensions: {
    ExtensionInstallForcelist = map (
      id: "${id};https://clients2.google.com/service/update2/crx"
    ) extensions;
  };
in
{
  options.programs.wavebox = {
    enable = mkEnableOption "Wavebox policy deployment";

    extensions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of Wavebox extensions to install.
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
        Additional Wavebox policy options.
      '';
      example = literalExpression ''
        {
          "PromptForDownloadLocation" = true;
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.etc."wavebox/policies/managed/extensions.json" = {
      text = builtins.toJSON (extensionJson cfg.extensions // cfg.extraOpts);
    };
  };
}
