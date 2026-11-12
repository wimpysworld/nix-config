{
  buildGoModule,
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  lib,
  makeBinaryWrapper,
  nodejs_24,
  pkg-config,
  pnpm_10_latest,
  pnpmConfigHook,
  stdenvNoCC,
  unstable,
  vips,
}:
buildGoModule (finalAttrs: {
  pname = "silo-server";
  version = "0-unstable-2026-11-12";

  src = fetchFromGitHub {
    owner = "Silo-Server";
    repo = "silo-server";
    rev = "0b579aa6192d49d7e8e0921dde5e955ac29ce302";
    hash = "sha256-aDOIqt51eS115GANE8WZ71bk+uYOIw6kxeKGH52Bi64=";
  };

  web = stdenvNoCC.mkDerivation (webAttrs: {
    pname = "${finalAttrs.pname}-web";
    inherit (finalAttrs) version src;

    pnpmRoot = "web";
    pnpmDeps = fetchPnpmDeps {
      inherit (webAttrs) pname version src;
      pnpm = pnpm_10_latest;
      fetcherVersion = 4;
      sourceRoot = "${finalAttrs.src.name}/web";
      hash = "sha256-ZL2JE7VwQ2Ey5TMGKLUR4LB7yAnuZjpDgADL2+NngRI=";
    };

    nativeBuildInputs = [
      nodejs_24
      pnpm_10_latest
      pnpmConfigHook
    ];

    # `scripts/typecheck.mjs` runs the prebuilt `@tsrs/linux-*-gnu` binary when
    # that optional dependency is installed, which fails on NixOS without
    # patching the ELF interpreter. Run `tsc -b` directly before `vite build`.
    postPatch = ''
      substituteInPlace web/package.json \
        --replace-fail '"build": "node scripts/typecheck.mjs && vite build",' \
          '"build": "tsc -b && vite build",'
    '';

    buildPhase = ''
      runHook preBuild
      pnpm --dir web run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -R web/dist $out
      runHook postInstall
    '';
  });

  vendorHash = "sha256-G5AcU3GyRXgxb7X7QcxWzGgFfh1a/+UsaDrQVKRJpak=";

  subPackages = [ "cmd/silo" ];

  nativeBuildInputs = [
    makeBinaryWrapper
    pkg-config
  ];

  buildInputs = [
    vips
  ];

  preBuild = ''
    rm -rf web/dist
    cp -R ${finalAttrs.web} web/dist
    chmod -R u+w web/dist
  '';

  overrideModAttrs = {
    preBuild = "";
  };

  ldflags = [
    "-s"
    "-w"
    "-X github.com/Silo-Server/silo-server/internal/buildinfo.revisionOverride=${finalAttrs.src.rev}"
    "-X github.com/Silo-Server/silo-server/internal/buildinfo.dirtyOverride=false"
  ];

  # Upstream integration tests require Docker testcontainers.
  doCheck = false;

  postInstall = ''
    wrapProgram "$out/bin/silo" \
      --prefix PATH : ${
        lib.makeBinPath [
          unstable.jellyfin-ffmpeg
          vips.bin
          git
          nodejs_24
        ]
      }
  '';

  meta = {
    description = "Self-hosted media server for films, series, audiobooks, ebooks, podcasts, and manga";
    homepage = "https://siloserver.org/";
    license = lib.licenses.agpl3Plus;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "silo";
    platforms = lib.platforms.linux;
  };
})
