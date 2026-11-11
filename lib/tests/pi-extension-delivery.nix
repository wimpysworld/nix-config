# Gate: checks.x86_64-linux.pi-extension-delivery, run by just check and CI.
# Load generated Home Manager links through Pi's canonicalising extension loader.
{
  pkgs,
  homeFiles,
  piPackage,
}:
pkgs.runCommand "pi-extension-delivery" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
  export HOME="$TMPDIR/home"
  export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
  export PI_TELEMETRY=0
  mkdir -p "$HOME"
  ln -s ${homeFiles}/.pi "$HOME/.pi"
  node ${./pi-extension-delivery.mjs} \
    ${piPackage}/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/extensions/loader.js
  touch "$out"
''
