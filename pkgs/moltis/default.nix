# Moltis publishes prebuilt release archives, so package the upstream
# platform tarball instead of building from the source flake. The
# archive carries the binary and its web assets under share/, which the
# server expects to find relative to the executable.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zlib,
  gcc-unwrapped,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "moltis";
  version = "20261023.01";

  src =
    finalAttrs.passthru.sources.${stdenv.hostPlatform.system}
      or (throw "moltis: no binary available for ${stdenv.hostPlatform.system}");

  # The archive holds the binary and share/ as siblings; keep the checkout root.
  sourceRoot = ".";

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook ++ [ makeWrapper ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    zlib
    gcc-unwrapped.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm0755 moltis "$out/bin/moltis"
    cp -r share "$out/share"
    runHook postInstall
  '';

  # The binary resolves web assets from MOLTIS_SHARE_DIR. Without the
  # wrapper it only looks in the working directory, its siblings, and
  # /usr/share/moltis, so it must point at the packaged assets. --set-default
  # lets a caller override the value with an explicit MOLTIS_SHARE_DIR.
  postInstall = ''
    wrapProgram "$out/bin/moltis" --set-default MOLTIS_SHARE_DIR "$out/share/moltis"
  '';

  passthru.sources =
    let
      base = "https://github.com/moltis-org/moltis/releases/download/${finalAttrs.version}/moltis-${finalAttrs.version}";
    in
    {
      x86_64-linux = fetchurl {
        url = "${base}-x86_64-unknown-linux-gnu.tar.gz";
        hash = "sha256-kDjdhkbZ3bItq+U7nRsWQ5vT9MVNgXuKyuYwnJEQ3CQ=";
      };
      aarch64-darwin = fetchurl {
        url = "${base}-aarch64-apple-darwin.tar.gz";
        hash = "sha256-E//zSc+59e9AaLpVGf3BngTJlY/mfoUx3UgXwMGZzFk=";
      };
      x86_64-darwin = fetchurl {
        url = "${base}-x86_64-apple-darwin.tar.gz";
        hash = "sha256-X4IN3NUlbuRfNzuAwpmM2l3ND+sL23wC/Our0lH0vYc=";
      };
    };

  meta = {
    description = "Secure persistent personal agent server";
    homepage = "https://moltis.org";
    changelog = "https://github.com/moltis-org/moltis/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "moltis";
    platforms = lib.attrNames finalAttrs.passthru.sources;
  };
})
