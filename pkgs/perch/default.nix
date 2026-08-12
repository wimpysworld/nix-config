{
  lib,
  fetchFromGitHub,
  makeWrapper,
  rustPlatform,
  stdenv,
  xdg-utils,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "perch";
  version = "0.3.4";

  src = fetchFromGitHub {
    owner = "ricardodantas";
    repo = "perch";
    rev = "9157400555c101d9cf1d0e74efa889bbd11424d6";
    hash = "sha256-TURpPI4Nj9xfTUEY90KCDgrGFjXGm+/n3cVxxOM709k=";
  };

  cargoHash = "sha256-pbVDG8Wm2K7Hhciq+6xYWbJWYU5CdrAqMXY2ZM1fgfs=";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ makeWrapper ];

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/perch \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  meta = {
    description = "Terminal social client for Mastodon and Bluesky";
    homepage = "https://github.com/ricardodantas/perch";
    changelog = "https://github.com/ricardodantas/perch/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "perch";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
