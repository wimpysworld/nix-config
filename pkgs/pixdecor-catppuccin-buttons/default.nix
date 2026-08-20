{
  catppuccin-gtk,
  imagemagick,
  librsvg,
  stdenvNoCC,
  buttonSize ? 18,
  glyphSize ? 16,
  normalBackgroundColor ? null,
  normalGlyphColor ? null,
  hoverGlyphColor ? null,
  minimiseHoverColor ? null,
  maximiseHoverColor ? null,
  closeHoverColor ? null,
}:
let
  defaultColors =
    (builtins.fromJSON (builtins.readFile ../../lib/catppuccin-palette.json)).mocha.colors;
  gtkAssets = "${catppuccin-gtk.src}/sources/colloid/src/assets/gtk/symbolics";
  normalBackground =
    if normalBackgroundColor == null then defaultColors.surface0.hex else normalBackgroundColor;
  normalGlyph = if normalGlyphColor == null then defaultColors.text.hex else normalGlyphColor;
  hoverGlyph = if hoverGlyphColor == null then defaultColors.crust.hex else hoverGlyphColor;
  minimiseHover = if minimiseHoverColor == null then defaultColors.yellow.hex else minimiseHoverColor;
  maximiseHover = if maximiseHoverColor == null then defaultColors.green.hex else maximiseHoverColor;
  closeHover = if closeHoverColor == null then defaultColors.red.hex else closeHoverColor;
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
      local active_background="$3"
      local glyph="$TMPDIR/$name-glyph.png"

      rsvg-convert --width ${toString glyphSize} --height ${toString glyphSize} \
        --output "$glyph" "$asset"

      magick -size ${toString buttonSize}x${toString buttonSize} xc:none \
        -fill "$active_background" \
        -draw "circle $(( ${toString buttonSize} / 2 )),$(( ${toString buttonSize} / 2 )) $(( ${toString buttonSize} / 2 )),1" \
        "PNG32:$out/share/pixdecor/buttons/$name.png"

      magick -size ${toString buttonSize}x${toString buttonSize} xc:none \
        -fill "$active_background" \
        -draw "circle $(( ${toString buttonSize} / 2 )),$(( ${toString buttonSize} / 2 )) $(( ${toString buttonSize} / 2 )),1" \
        \( "$glyph" -fill "${hoverGlyph}" -colorize 100 \) \
        -gravity center -composite \
        "PNG32:$out/share/pixdecor/buttons/$name-hover.png"

      magick -size ${toString buttonSize}x${toString buttonSize} xc:none \
        -fill "${normalBackground}" \
        -draw "circle $(( ${toString buttonSize} / 2 )),$(( ${toString buttonSize} / 2 )) $(( ${toString buttonSize} / 2 )),1" \
        "PNG32:$out/share/pixdecor/buttons/$name-inactive.png"

      magick -size ${toString buttonSize}x${toString buttonSize} xc:none \
        -fill "${normalBackground}" \
        -draw "circle $(( ${toString buttonSize} / 2 )),$(( ${toString buttonSize} / 2 )) $(( ${toString buttonSize} / 2 )),1" \
        \( "$glyph" -fill "${normalGlyph}" -colorize 100 \) \
        -gravity center -composite \
        "PNG32:$out/share/pixdecor/buttons/$name-inactive-hover.png"
    }

    make_button minimize "${gtkAssets}/minimize-symbolic.svg" "${minimiseHover}"
    make_button maximize "${gtkAssets}/maximize-symbolic.svg" "${maximiseHover}"
    make_button restore "${gtkAssets}/unmaximize-symbolic.svg" "${maximiseHover}"
    make_button close "${gtkAssets}/close-symbolic.svg" "${closeHover}"

    runHook postInstall
  '';

  passthru = {
    inherit buttonSize glyphSize;
  };
}
