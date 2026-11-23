{
  catppuccinPalette,
  lib ? pkgs.lib,
  pkgs,
  herdrDispModelBin ? (
    if
      (pkgs ? herdr-disp-model) && (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.herdr-disp-model)
    then
      pkgs.writeShellScript "herdr-disp-model" ''
        exec ${pkgs.herdr-disp-model.passthru.hookCommand} "$@"
      ''
    else
      ""
  ),
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
    AGY_STATUSLINE_HERDR_DISP_MODEL_DEFAULT = "${herdrDispModelBin}";
  };
  text = builtins.readFile ./agy-statusline.sh;
}
