_: {
  imports = [ ./gpd-generic.nix ];
  
  # Many GPD devices uses a tablet displays that are mounted rotated 90° counter-clockwise
  boot.kernelParams = [ "video=DSI-1:panel_orientation=right_side_up" ];
}
