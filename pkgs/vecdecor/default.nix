{
  lib,
  stdenv,
  fetchFromGitHub,
  gettext,
  meson,
  ninja,
  pkg-config,
  cairo,
  glm,
  libdrm,
  libglvnd,
  librsvg,
  libxkbcommon,
  pango,
  wayfire,
}:
let
  sources = {
    "0.10.1" = {
      version = "0.10.0";
      rev = "fc1eb4ba4c7c479fc1fe740f2d6374d506ea885e";
      hash = "sha256-Lh/ZidgyLoRza0jOM6xubWCSSifsVkof6Q0Rh57iiPY=";
      wayfireConstraint = "['>=0.10.1', '<0.11.0']";
    };
    "0.11.0" = {
      version = "0.11.0";
      rev = "0e5266b78709b51880dc4c08080e2d43cccf9269";
      hash = "sha256-ZcoidklD72pr8NYf+t81l3XfOlTi6piSdHvdNNiaopI=";
      wayfireConstraint = "['>=0.11.0', '<0.12.0']";
    };
  };
  source =
    sources.${wayfire.version}
      or (throw "vecdecor: unsupported Wayfire version ${wayfire.version}; supported versions are 0.10.1 and 0.11.0");
in
stdenv.mkDerivation {
  pname = "vecdecor";
  inherit (source) version;

  src = fetchFromGitHub {
    owner = "wimpysworld";
    repo = "vecdecor";
    inherit (source) rev hash;
  };

  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail \
        "wayfire = dependency('wayfire', version: ${source.wayfireConstraint})" \
        "wayfire = dependency('wayfire', version: '=${wayfire.version}')" \
      --replace-fail \
        "librsvg = dependency('librsvg-2.0')" \
        $'librsvg = dependency(\'librsvg-2.0\')\npango = dependency(\'pango\')\npangocairo = dependency(\'pangocairo\')'

    substituteInPlace src/meson.build \
      --replace-fail \
        "dependencies: [wayfire, deco_geometry_dep, deco_button_renderer_dep]," \
        "dependencies: [wayfire, cairo, librsvg, pango, pangocairo, deco_geometry_dep, deco_button_renderer_dep],"
  '';

  nativeBuildInputs = [
    gettext
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    cairo
    glm
    libdrm
    libglvnd
    librsvg
    libxkbcommon
    pango
    wayfire
  ];

  env.PKG_CONFIG_WAYFIRE_METADATADIR = "${placeholder "out"}/share/wayfire/metadata";

  doCheck = true;
  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    test -f "$out/lib/wayfire/libvecdecor.so"
    test -f "$out/share/wayfire/metadata/vecdecor.xml"
    runHook postInstallCheck
  '';

  meta = {
    description = "Vector window decoration plugin for Wayfire";
    homepage = "https://github.com/wimpysworld/vecdecor";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.linux;
  };
}
