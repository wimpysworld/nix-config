{ lib }:

let
  paletteJson = builtins.fromJSON (builtins.readFile ./catppuccin-palette.json);

  flavours = [
    "latte"
    "frappe"
    "macchiato"
    "mocha"
  ];

  mkVtmTheme =
    flavour:
    let
      flavourData = paletteJson.${flavour};
      colours = flavourData.colors;
      isDark = flavourData.dark;
      c = colourName: colours.${colourName}.hex;
      withAlpha =
        colourName: alpha:
        let
          colour = c colourName;
        in
        "${colour}${alpha}";
      onAccent = if isDark then c "base" else c "crust";
      selectionStyle = {
        fx = "color";
        inverse = true;
        foreground = c "text";
        background = c "surface2";
      };
    in
    {
      cursor.color = {
        foreground = c "base";
        background = c "rosewater";
      };

      colors = {
        window = {
          foreground = c "text";
          background = c "surface0";
        };
        focus = {
          foreground = onAccent;
          background = c "blue";
        };
        brighter = {
          foreground = c "text";
          background = c "surface2";
          alpha = 60;
        };
        shadower.background = withAlpha "crust" "B4";
        warning = {
          foreground = onAccent;
          background = c "yellow";
        };
        danger = {
          foreground = onAccent;
          background = c "red";
        };
        action = {
          foreground = onAccent;
          background = c "green";
        };
      };

      desktop = {
        background.color = {
          foreground = c "overlay0";
          background = withAlpha "base" "FF";
        };

        taskbar.colors = {
          background = {
            foreground = c "subtext1";
            background = withAlpha "mantle" "C0";
          };
          focused.foreground = c "green";
          selected.foreground = c "text";
          active.foreground = c "blue";
          inactive = {
            foreground = c "overlay0";
            background = "Transparent";
          };
        };
      };

      terminal.colors = {
        palette = map c [
          "surface1"
          "red"
          "green"
          "yellow"
          "blue"
          "pink"
          "teal"
          "subtext1"
          "surface2"
          "red"
          "green"
          "yellow"
          "blue"
          "pink"
          "teal"
          "subtext0"
        ];
        default = {
          foreground = c "text";
          background = c "base";
        };
        match = {
          fx = "color";
          foreground = onAccent;
          background = c "green";
        };
        selection = {
          text = selectionStyle;
          protected = selectionStyle;
          ansi = selectionStyle;
          rich = selectionStyle;
          html = selectionStyle;
          none = {
            fx = "color";
            inverse = true;
            foreground = c "overlay0";
            background = c "surface0";
          };
        };
      };
    };
in
{
  inherit flavours;

  themes = builtins.listToAttrs (
    map (flavour: {
      name = "catppuccin-${flavour}";
      value = mkVtmTheme flavour;
    }) flavours
  );
}
