# Prebuilt Reverse Engineer Anything (REA)-verified Kuna binary (v1.1000).
#
# Packaged from official GitHub release tarballs to avoid compiling Kuna's Rust
# workspace and SLEIGH specs from source while NixOS/nixpkgs#590267 (`kuna:
# 1.992 -> 1.1000`) is pending in nixpkgs-unstable. Replace with
# `final.unstable.kuna` once 1.1000 reaches nixpkgs-unstable.
{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
}:

let
  version = "1.1000";
  inherit (stdenv.hostPlatform) system;

  sources = {
    x86_64-linux = {
      name = "kuna-v${version}-linux-x86_64-musl.tar.gz";
      hash = "sha256-309rSspE82KP7T9TkQn5CzMuvBvUQnr3/qXxCoKu2DA=";
    };
    aarch64-linux = {
      name = "kuna-v${version}-linux-arm64.tar.gz";
      hash = "sha256-flMMNgz07NUpyIebLbzcpAIB4Y/cwgAq5ayM8XL+FrU=";
    };
    aarch64-darwin = {
      name = "kuna-v${version}-macos-arm64.tar.gz";
      hash = "sha256-6I6qhg1pcGptnC7yivInQkM1ZnOXzKVShcmWn1hiATM=";
    };
  };

  source = sources.${system} or (throw "kuna-bin: unsupported system ${system}");
in
stdenv.mkDerivation {
  pname = "kuna-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Noelo-Lab/kuna/releases/download/v${version}/${source.name}";
    inherit (source) hash;
  };

  # Preserve the embedded compiled SLEIGH specs inside the self-contained binary.
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isAarch64 (
    lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ]
  );

  buildInputs = lib.optionals (stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64) [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 kuna "$out/bin/kuna"
    install -Dm644 LICENSE NOTICE -t "$out/share/licenses/kuna-bin"

    runHook postInstall
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck

    reported="$("$out/bin/kuna" --version)"
    if [[ "$reported" != "kuna ${version}" ]]; then
      echo "kuna-bin: expected 'kuna ${version}', got '$reported'" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "Agent-first binary decompiler based on Ghidra (prebuilt release)";
    homepage = "https://kuna.noelo.org";
    changelog = "https://github.com/Noelo-Lab/kuna/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "kuna";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
