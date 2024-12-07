{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
  writeScript,
  libGL,
  libGLU,
  libstdcxx5,
  libX11,
  libXext,
  libXi,
}:
stdenv.mkDerivation rec {
  pname = "defold-gdc";
  version = "1.9.3";

  src = fetchurl {
    url = "https://github.com/defold/defold/releases/download/${version}/gdc-linux";
    hash = "sha256-rBBfgeea/3MHJ8PM63P1DYKh8Vm0IZWXdYR/TfEWBa8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    libXext
    libX11
    libXi
    libGL
    libGLU
    libstdcxx5
  ];

  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -m 755 -D $src $out/bin/defold-gdc
    runHook postInstall
  '';

  passthru = {
    updateScript = writeScript "update.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p curl jq nix-update
      version=$(curl -s https://d.defold.com/editor-alpha/info.json | jq -r .version)
      nix-update defold-gdc --version "$version"
    '';
  };

  meta = {
    description = "Defold gamepad calibration tool";
    homepage = "https://defold.com/";
    license = lib.licenses.free;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "defold-gdc";
  };
}
