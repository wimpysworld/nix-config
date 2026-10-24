# The brightnessctl udev rules give the video group write access to backlight
# brightness and the input group write access to LED brightness, so tools that
# write to /sys/class/backlight and /sys/class/leds need no root. A host with
# no backlight device gets no match, so the rules are harmless there.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.noughty.host.is.workstation {
  services.udev.packages = [ pkgs.brightnessctl ];
  # The users mixin already adds the input group.
  users.users.${config.noughty.user.name}.extraGroups = [ "video" ];
}
