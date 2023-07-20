{ desktop, ... }: {
  imports = [
    ./audio-recorder.nix
    ./celluloid.nix
    ./dconf-editor.nix
    ./emote.nix
    ./gitkraken.nix
    ./gnome-sound-recorder.nix
    ./meld.nix
    ./rhythmbox.nix
    ./tilix.nix
    (./. + "/${desktop}.nix")
  ];

  xresources.properties = {
    "XTerm*background" = "#121214";
    "XTerm*foreground" = "#c8c8c8";
    "XTerm*cursorBlink" = true;
    "XTerm*cursorColor" = "#FFC560";
    "XTerm*boldColors" = false;

    #Black + DarkGrey
    "*color0" = "#141417";
    "*color8" = "#434345";
    #DarkRed + Red
    "*color1" = "#D62C2C";
    "*color9" = "#DE5656";
    #DarkGreen + Green
    "*color2" = "#42DD76";
    "*color10" = "#A1EEBB";
    #DarkYellow + Yellow
    "*color3" = "#FFB638";
    "*color11" = "#FFC560";
    #DarkBlue + Blue
    "*color4" = "#28A9FF";
    "*color12" = "#94D4FF";
    #DarkMagenta + Magenta
    "*color5" = "#E66DFF";
    "*color13" = "#F3B6FF";
    #DarkCyan + Cyan
    "*color6" = "#14E5D4";
    "*color14" = "#A1F5EE";
    #LightGrey + White
    "*color7" = "#c8c8c8";
    "*color15" = "#e9e9e9";
    "XTerm*faceName" = "FiraCode Nerd Font:size=13:style=Medium:antialias=true";
    "XTerm*boldFont" = "FiraCode Nerd Font:size=13:style=Bold:antialias=true";
    "XTerm*geometry" = "132x50";
    "XTerm.termName" = "xterm-256color";
    "XTerm*locale" = false;
    "XTerm*utf8" = true;
  };
}
