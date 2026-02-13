{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  libtsm,
  systemdLibs,
  libxkbcommon,
  libdrm,
  libGLU,
  libGL,
  pango,
  pixman,
  pkg-config,
  docbook_xsl,
  libxslt,
  libgbm,
  ninja,
  check,
  buildPackages,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "kmscon";
  version = "9.3.2";

  src = fetchFromGitHub {
    owner = "kmscon";
    repo = "kmscon";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-a1H9/j92Z/vjvFp226Ps9PFy5dAS8yg+RErgJWIb9HQ=";
  };

  strictDeps = true;

  depsBuildBuild = [
    buildPackages.stdenv.cc
  ];

  buildInputs = [
    check
    libdrm
    libgbm
    libGLU
    libGL
    libtsm
    libxkbcommon
    pango
    pixman
    systemdLibs
  ];

  nativeBuildInputs = [
    docbook_xsl
    libxslt
    meson
    ninja
    pkg-config
  ];

  mesonFlags = [
    "--sysconfdir=${placeholder "out"}/etc"
  ];

  # The upstream meson.build resolves systemdsystemunitdir from the systemd
  # pkg-config dependency, which points into the read-only systemd-libs store
  # path. Override it to install systemd units into the package's own output.
  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail \
        "systemdsystemunitdir = systemd_deps.get_variable('systemdsystemunitdir', default_value: 'lib/systemd/system')" \
        "systemdsystemunitdir = get_option('prefix') / 'lib/systemd/system'"
  '';

  enableParallelBuilding = true;

  meta = with lib; {
    description = "KMS/DRM based System Console";
    mainProgram = "kmscon";
    homepage = "https://github.com/kmscon/kmscon";
    license = licenses.mit;
    maintainers = with maintainers; [ flexiondotorg ];
    platforms = platforms.linux;
  };
})
