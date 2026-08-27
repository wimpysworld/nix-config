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
  wf-config,
}:
let
  sources = {
    "0.10.1" = {
      version = "0.10.0";
      rev = "eec39739905e7b8e1fc73324a50eebedb649f48f";
      hash = "sha256-4ymcZz2QVOCWCA/SEj04oaDGEJezGdCLI0wJdm5XJtU=";
      wayfireConstraint = "['>=0.10.1', '<0.11.0']";
    };
    "0.11.0" = {
      version = "0.11.0";
      rev = "33391f81343dc18698445a2a3e07e2caa5468b0e";
      hash = "sha256-jaTcqWWm6VJYBV7COfXsz3y31TDh9M1Q5NGGMCg5AZg=";
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
    wf-config
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
