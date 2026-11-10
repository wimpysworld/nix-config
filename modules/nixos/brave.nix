{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.chromium;
  hasDefaultProfile = lib.any (value: value != null) [
    cfg.homepageLocation
    cfg.defaultSearchProviderEnabled
    cfg.defaultSearchProviderSearchURL
    cfg.defaultSearchProviderSuggestURL
    cfg.extensions
  ];
  appId = "com.github.browserpass.native.json";
in
{
  environment.etc = lib.mkMerge [
    (lib.mkIf cfg.enable {
      "brave/policies/managed/default.json" = lib.mkIf hasDefaultProfile {
        text = lib.mkDefault config.environment.etc."chromium/policies/managed/default.json".text;
      };
      "brave/policies/managed/extra.json" = lib.mkIf (cfg.extraOpts != { }) {
        text = lib.mkDefault config.environment.etc."chromium/policies/managed/extra.json".text;
      };
    })
    (lib.mkIf config.programs.browserpass.enable {
      "opt/brave/native-messaging-hosts/${appId}".source =
        "${pkgs.browserpass}/lib/browserpass/hosts/chromium/${appId}";
      "opt/brave/policies/managed/${appId}".source =
        "${pkgs.browserpass}/lib/browserpass/policies/chromium/${appId}";
    })
  ];
}
