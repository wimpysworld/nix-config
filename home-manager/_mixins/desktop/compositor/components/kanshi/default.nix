{
  config,
  lib,
  ...
}:
let
  inherit (config.noughty) host;
  fixedDisplays = lib.filter (d: !d.hotplug) host.displays;
  # Turn a registry display into a kanshi output directive. The match criteria
  # falls back to the connector name when no description is set.
  mkOutput = d: {
    criteria = if d.match != null then d.match else d.output;
    status = "enable";
    mode = "${toString d.width}x${toString d.height}@${toString d.refresh}Hz";
    position = "${toString d.position.x},${toString d.position.y}";
    inherit (d) scale;
  };
  # The registry positions encode the docked layout, so a lone fixed display
  # moves back to the origin when the hot-pluggable displays are absent.
  mkUndockedOutput =
    d: mkOutput d // lib.optionalAttrs (builtins.length fixedDisplays == 1) { position = "0,0"; };
in
lib.mkIf (host.is.linux && host.display.hasHotplug) {
  # kanshi speaks wlr-output-management, so these profiles work under any
  # wlroots compositor. A kanshi profile matches only when the connected
  # outputs are exactly the outputs it lists.
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile.name = "undocked";
        profile.outputs = map mkUndockedOutput fixedDisplays;
      }
      {
        profile.name = "docked";
        profile.outputs = map mkOutput host.displays;
      }
    ];
  };
}
