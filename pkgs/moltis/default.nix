# Moltis publishes prebuilt release archives, so package the upstream
# x86_64-linux GNU tarball instead of building from the source flake. The
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
  version = "20260913.02";

  src = fetchurl {
    url = "https://github.com/moltis-org/moltis/releases/download/${finalAttrs.version}/moltis-${finalAttrs.version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-aljDxPoSM/0S8H9Ot3dfSh+6hNPUW7rQi618gEb4jI0=";
  };

  # The archive holds the binary and share/ as siblings; keep the checkout root.
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
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

  meta = {
    description = "Secure persistent personal agent server";
    homepage = "https://moltis.org";
    changelog = "https://github.com/moltis-org/moltis/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "moltis";
    platforms = [ "x86_64-linux" ];
  };
})
