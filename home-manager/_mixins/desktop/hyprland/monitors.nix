_: {
  phasma = {
    monitor = [
      "DP-1, 3440x1440@100Hz, 0x1280, 1"
      "DP-2, 1920x1080@60Hz, 760x3040, 1"
      "HDMI-A-1, 2560x1600@120Hz, 1920x0, 1.25"
    ];
    workspace = [
      "1, name:Web, persistent:true, monitor:DP-1"
      "2, name:Work, persistent:true, monitor:DP-1"
      "3, name:Chat, persistent:true, monitor:DP-1"
      "4, name:Code, persistent:true, monitor:DP-1"
      "5, name:Term, persistent:true, monitor:DP-1"
      "6, name:Virt, persistent:true, monitor:DP-1"
      "7, name:Cast, persistent:true, monitor:DP-1"
      "8, name:Fun, persistent:true, monitor:DP-1"
      "9, name:Camera, persistent:true, monitor:HDMI-A-1, layoutopt:orientation:left"
      "10,name:Stream, persistent:true, monitor:DP-2"
    ];
  };
  shaa = {
    monitor = [ "eDP-1, 1920x1080@60Hz, auto, 1" ];
    workspace = [
      "1, name:Web, persistent:true, monitor:eDP-1"
      "2, name:Work, persistent:true, monitor:eDP-1"
      "3, name:Chat, persistent:true, monitor:eDP-1"
      "4, name:Code, persistent:true, monitor:eDP-1"
      "5, name:Term, persistent:true, monitor:eDP-1"
      "6, name:Virt, persistent:true, monitor:eDP-1"
      "7, name:Cast, persistent:true, monitor:eDP-1"
      "8, name:Fun, persistent:true, monitor:eDP-1"
    ];
  };
  tanis = {
    monitor = [ "eDP-1, 1920x1200@60Hz, auto, 1" ];
    workspace = [
      "1, name:Web, persistent:true, monitor:eDP-1"
      "2, name:Work, persistent:true, monitor:eDP-1"
      "3, name:Chat, persistent:true, monitor:eDP-1"
      "4, name:Code, persistent:true, monitor:eDP-1"
      "5, name:Term, persistent:true, monitor:eDP-1"
      "6, name:Virt, persistent:true, monitor:eDP-1"
      "7, name:Cast, persistent:true, monitor:eDP-1"
      "8, name:Fun, persistent:true, monitor:eDP-1"
    ];
  };
  vader = {
    monitor = [
      "DP-1, 2560x2880@60Hz, 0x0, 1"
      "DP-2, 2560x2880@60Hz, 2560x0, 1"
      "DP-3, 1920x1080@60Hz, 320x2880, 1"
    ];
    workspace = [
      "1, name:Web, persistent:true, monitor:DP-1"
      "2, name:Work, persistent:true, monitor:DP-1"
      "3, name:Chat, persistent:true, monitor:DP-2"
      "4, name:Code, persistent:true, monitor:DP-2"
      "5, name:Term, persistent:true, monitor:DP-2"
      "6, name:Virt, persistent:true, monitor:DP-2"
      "7, name:Cast, persistent:true, monitor:DP-1"
      "8, name:Fun, persistent:true, monitor:DP-1"
      "9, name:Camera, persistent:true, monitor:DP-2"
      "10,name:Stream, persistent:true, monitor:DP-3"
    ];
  };
}
