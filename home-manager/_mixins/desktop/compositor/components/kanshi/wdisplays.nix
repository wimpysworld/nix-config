# wdisplays saves display layouts as kanshi profiles in a user-writable file
# that the kanshi configuration includes. wdisplays resolves symlinks before it
# writes, so the file must live outside the Nix store. The kanshi component,
# the compositor hub and the Fuzzel control center import this file, so they
# share one path and one package.
{ config, pkgs }:
rec {
  configFile = "${config.xdg.stateHome}/kanshi/wdisplays.conf";

  package = pkgs.symlinkJoin {
    inherit (pkgs.wdisplays) version meta;
    pname = "wdisplays-kanshi";
    paths = [ pkgs.wdisplays ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wdisplays \
        --set WDISPLAYS_KANSHI_CONFIG ${pkgs.lib.escapeShellArg configFile}
    '';
  };
}
