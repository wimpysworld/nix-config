{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  name = builtins.baseNameOf (builtins.toString ./.);
in
{
  home.packages = lib.mkIf (host.is.linux && host.is.workstation) (
    let
      compositor = lib.attrByPath [
        host.desktop
      ] null (import ../../../../lib/wayland-compositors.nix).compositors;
      shellApplication = pkgs.writeShellApplication {
        inherit name;
        text =
          builtins.replaceStrings
            [ "@portalService@" ]
            [
              (lib.optionalString (compositor != null) compositor.portal.service)
            ]
            (builtins.readFile ./${name}.sh);
      };
    in
    [ shellApplication ]
  );
}
