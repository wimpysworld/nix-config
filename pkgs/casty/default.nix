# Casty is a TTY web browser that drives headless Chrome over raw CDP and
# renders frames with the Kitty graphics protocol. It is plain Node.js with a
# single npm dependency (ws), so the derivation vendors that module directly
# rather than pulling in a lockfile-based builder.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  nodejs,
  chromium,
  which,
}:
let
  # The only runtime npm dependency; ws itself has no further dependencies.
  wsVersion = "8.21.1";
  wsSrc = fetchurl {
    url = "https://registry.npmjs.org/ws/-/ws-${wsVersion}.tgz";
    hash = "sha256-uw9+WLofZHRmcnNNNhdf4YXyJkkeM2q8B0PiqPRHLsE=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "casty";
  version = "1.2.2";

  src = fetchFromGitHub {
    owner = "sanohiro";
    repo = "casty";
    rev = "v${finalAttrs.version}";
    hash = "sha256-XDVpK1bvMSgtb/i5FRRnPJJmm1oWxF3wMU+oCDabr8k=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Node.js is needed so fixup can resolve the "env node" shebang in casty.js.
  buildInputs = [ nodejs ];

  # Upstream's bin/casty shell launcher downloads a prebuilt Chrome Headless
  # Shell into ~/.casty, which cannot run unpatched on NixOS. Instead, wrap
  # bin/casty.js directly with CASTY_ENSURE_CHROME set so the downloader is
  # skipped, and put chromium on PATH so findChrome in lib/chrome.js resolves
  # it via which as the system browser fallback.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/casty/node_modules/ws" "$out/bin"
    cp -r bin lib package.json LICENSE "$out/lib/casty/"
    tar xzf ${wsSrc} --strip-components=1 -C "$out/lib/casty/node_modules/ws"
    makeWrapper "$out/lib/casty/bin/casty.js" "$out/bin/casty" \
      --set CASTY_ENSURE_CHROME 1 \
      --prefix PATH : ${
        lib.makeBinPath [
          chromium
          which
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "TTY web browser using raw CDP and the Kitty graphics protocol";
    homepage = "https://github.com/sanohiro/casty";
    license = lib.licenses.mit;
    mainProgram = "casty";
    # Chromium in nixpkgs is Linux-only, and the wrapper depends on it.
    platforms = lib.platforms.linux;
  };
})
