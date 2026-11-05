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
  version = "0-unstable-2026-11-05";

  src = fetchFromGitHub {
    owner = "Silo-Server";
    repo = "silo-server";
    rev = "2d5f22e7d704799e3bd456e1517d6e5cee3cfbc5";
    hash = "sha256-CFtPlDyEhDtHrXSF1XsywXq3Q8MCzxv98CkVmidIvUk=";
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
      hash = "sha256-Lv2FcihUsmdZU2SLlrLivrY3zc2J8PQo4i0kKitT2V0=";
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

  vendorHash = "sha256-lYDdVcE21FuE+/AWuJBkIraf37N68Bsc5vTMVgYfw8k=";

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
