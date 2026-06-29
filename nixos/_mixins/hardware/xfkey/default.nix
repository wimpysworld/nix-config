{
  config,
  lib,
  noughtyLib,
  ...
}:
let
  inherit (config.noughty) host;
in
lib.mkIf (!host.is.iso && noughtyLib.hostHasTag "xfkey") {
  # The XFFP XFKEY single-button USB key (0xaf88 0x6688) emits Enter.
  # Remap it to Pause (keycode 127), scoped to this device by VID:PID so
  # other keyboards are untouched. Voxtype listens on Pause.
  services.keyd = {
    enable = true;
    keyboards.xfkey = {
      ids = [ "af88:6688" ];
      settings.main.enter = "code:127";
    };
  };
}
