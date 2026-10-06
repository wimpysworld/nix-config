{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  apps = lib.optionalAttrs (noughtyLib.isUser [ "martin" ]) {
    "LastPass for Safari" = 6504626762;
    "uBlock Origin Lite" = 6745342698;
    "Consent-O-Matic" = 1606897889;
    "Kagi for Safari" = 1622835804;
  };
  manifest = pkgs.writeTextDir "share/mas/manifest.tsv" (
    lib.concatStrings (lib.mapAttrsToList (name: id: "${toString id}\t${name}\n") apps)
  );
  installer = pkgs.writeShellApplication {
    name = "switch-mas";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.mas
    ];
    text = ''
      primary_user=${lib.escapeShellArg config.system.primaryUser}
      manifest=${lib.escapeShellArg "${manifest}/share/mas/manifest.tsv"}
    ''
    + builtins.readFile ./switch-mas.sh;
  };
in
{
  system.build.mas = pkgs.symlinkJoin {
    name = "mac-app-store-apps";
    paths = [
      installer
      manifest
    ];
    passthru = { inherit apps installer manifest; };
  };
}
