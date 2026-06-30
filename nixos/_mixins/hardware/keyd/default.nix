{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
  enableKeyd = !host.is.iso && noughtyLib.hostHasTag "keyd";
in
lib.mkIf enableKeyd {
  services.keyd = {
    enable = true;

    keyboards = {
      # Kensington SlimBlade Pro Trackball, scoped by VID:PID.
      slimbladeProTrackball = {
        ids = [
          "m:047d:80d6"
          "m:047d:80d7"
        ];
        settings.main = {
          leftmouse = "rightmouse";
          rightmouse = "leftmouse";
          mouse1 = "middlemouse";
        };
      };

      # The XFFP XFKEY single-button USB key emits Enter. Voxtype listens on Pause.
      xfkey = {
        ids = [ "af88:6688" ];
        settings.main.enter = "pause";
      };
    };
  };
}
