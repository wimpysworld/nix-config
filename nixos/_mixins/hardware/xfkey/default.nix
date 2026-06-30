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
  # Remap it to Pause, scoped to this device by VID:PID so other keyboards
  # are untouched. keyd works at evdev level, so the key name is "pause"
  # (kernel keycode 119); the X11 keycode 127 is the same physical key.
  # Voxtype listens on Pause.
  services.keyd = {
    enable = true;
    keyboards.xfkey = {
      ids = [ "af88:6688" ];
      settings.main.enter = "pause";
    };
  };
}
