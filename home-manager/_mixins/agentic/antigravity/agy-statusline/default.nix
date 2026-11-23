{
  catppuccinPalette,
  pkgs,
}:
let
  ansiFg =
    colorName:
    let
      rgb = catppuccinPalette.getRGB colorName;
    in
    "38;2;${toString rgb.r};${toString rgb.g};${toString rgb.b}";
in
pkgs.writeShellApplication {
  name = "agy-statusline";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.jq
  ];
  runtimeEnv = {
    AGY_STATUSLINE_COLOR_MODEL = ansiFg "yellow";
    AGY_STATUSLINE_COLOR_PROJECT = ansiFg "green";
    AGY_STATUSLINE_COLOR_COST = ansiFg "red";
    AGY_STATUSLINE_COLOR_CONTEXT = ansiFg "peach";
    AGY_STATUSLINE_COLOR_ISOLATION = ansiFg "mauve";
    AGY_STATUSLINE_COLOR_SEPARATOR = ansiFg "overlay0";
  };
  text = builtins.readFile ./agy-statusline.sh;
}
