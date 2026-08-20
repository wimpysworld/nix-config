{
  catppuccin-gtk,
  imagemagick,
  librsvg,
  stdenvNoCC,
  canvasSize ? 34,
  buttonSize ? 30,
  circleRadius ? 7,
  glyphSize ? 16,
  hoverCornerRadius ? 6,
  activeGlyphColor ? null,
  inactiveCircleColor ? null,
  inactiveGlyphColor ? null,
  hoverBackgroundColor ? null,
  minimiseCircleColor ? null,
  maximiseCircleColor ? null,
  closeCircleColor ? null,
}:
let
  defaultColors =
    (builtins.fromJSON (builtins.readFile ../../lib/catppuccin-palette.json)).mocha.colors;
  buttonCentreWhole = builtins.div canvasSize 2 - 1;
  buttonCentre = "${toString buttonCentreWhole}.5";
  buttonOffset = builtins.div (canvasSize - buttonSize) 2;
  buttonMin = toString buttonOffset;
  buttonMax = toString (buttonOffset + buttonSize - 1);
  circleTop = "${toString (buttonCentreWhole - circleRadius)}.5";
  gtkAssets = "${catppuccin-gtk.src}/sources/colloid/src/assets/gtk/symbolics";
  activeGlyph = if activeGlyphColor == null then defaultColors.text.hex else activeGlyphColor;
  inactiveCircle =
    if inactiveCircleColor == null then defaultColors.surface1.hex else inactiveCircleColor;
  inactiveGlyph =
    if inactiveGlyphColor == null then defaultColors.subtext0.hex else inactiveGlyphColor;
  hoverBackground =
    if hoverBackgroundColor == null then defaultColors.surface0.hex else hoverBackgroundColor;
  minimiseCircle =
    if minimiseCircleColor == null then defaultColors.yellow.hex else minimiseCircleColor;
  maximiseCircle =
    if maximiseCircleColor == null then defaultColors.green.hex else maximiseCircleColor;
  closeCircle = if closeCircleColor == null then defaultColors.red.hex else closeCircleColor;
in
stdenvNoCC.mkDerivation {
  pname = "pixdecor-catppuccin-buttons";
  inherit (catppuccin-gtk) version;

  dontUnpack = true;

  nativeBuildInputs = [
    imagemagick
    librsvg
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/pixdecor/buttons"

    make_button() {
      local name="$1"
      local asset="$2"
      local active_circle="$3"
      local glyph="$TMPDIR/$name-glyph.png"

      rsvg-convert --width ${toString glyphSize} --height ${toString glyphSize} \
        --output "$glyph" "$asset"

      magick -size ${toString canvasSize}x${toString canvasSize} xc:none \
        -fill "$active_circle" \
        -draw "circle ${buttonCentre},${buttonCentre} ${buttonCentre},${circleTop}" \
        \( "$glyph" -fill "${activeGlyph}" -colorize 100 \) \
        -gravity center -composite \
        "PNG32:$out/share/pixdecor/buttons/$name.png"

      magick -size ${toString canvasSize}x${toString canvasSize} xc:none \
        -fill "${hoverBackground}" \
        -draw "roundrectangle ${buttonMin},${buttonMin} ${buttonMax},${buttonMax} ${toString hoverCornerRadius},${toString hoverCornerRadius}" \
        -fill "$active_circle" \
        -draw "circle ${buttonCentre},${buttonCentre} ${buttonCentre},${circleTop}" \
        \( "$glyph" -fill "${activeGlyph}" -colorize 100 \) \
        -gravity center -composite \
        "PNG32:$out/share/pixdecor/buttons/$name-hover.png"

      magick -size ${toString canvasSize}x${toString canvasSize} xc:none \
        -fill "${inactiveCircle}" \
        -draw "circle ${buttonCentre},${buttonCentre} ${buttonCentre},${circleTop}" \
        \( "$glyph" -fill "${inactiveGlyph}" -colorize 100 \) \
        -gravity center -composite \
        "PNG32:$out/share/pixdecor/buttons/$name-inactive.png"

      magick -size ${toString canvasSize}x${toString canvasSize} xc:none \
        -fill "${hoverBackground}" \
        -draw "roundrectangle ${buttonMin},${buttonMin} ${buttonMax},${buttonMax} ${toString hoverCornerRadius},${toString hoverCornerRadius}" \
        -fill "${inactiveCircle}" \
        -draw "circle ${buttonCentre},${buttonCentre} ${buttonCentre},${circleTop}" \
        \( "$glyph" -fill "${inactiveGlyph}" -colorize 100 \) \
        -gravity center -composite \
        "PNG32:$out/share/pixdecor/buttons/$name-inactive-hover.png"
    }

    make_button minimize "${gtkAssets}/minimize-symbolic.svg" "${minimiseCircle}"
    make_button maximize "${gtkAssets}/maximize-symbolic.svg" "${maximiseCircle}"
    make_button restore "${gtkAssets}/unmaximize-symbolic.svg" "${maximiseCircle}"
    make_button close "${gtkAssets}/close-symbolic.svg" "${closeCircle}"

    runHook postInstall
  '';

  passthru = {
    inherit
      canvasSize
      buttonSize
      circleRadius
      glyphSize
      hoverCornerRadius
      ;
  };
}
