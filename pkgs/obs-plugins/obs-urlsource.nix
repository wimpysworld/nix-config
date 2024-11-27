{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  curl,
  git,
  obs-studio,
  pugixml,
  qtbase,
  writeScript,
}:

let
  websocketpp = fetchFromGitHub {
    owner = "zaphoyd";
    repo = "websocketpp";
    rev = "0.8.2";
    sha256 = "sha256-9fIwouthv2GcmBe/UPvV7Xn9P2o0Kmn2hCI4jCh0hPM=";
  };

  lexbor = fetchFromGitHub {
    owner = "lexbor";
    repo = "lexbor";
    rev = "v2.3.0";
    sha256 = "sha256-s5fZWBhXC0fuHIUk1YX19bHagahOtSLlKQugyHCIlgI=";
  };

  asio = fetchFromGitHub {
    owner = "chriskohlhoff";
    repo = "asio";
    rev = "asio-1-28-0";
    sha256 = "sha256-dkiUdR8FgDnnqdptaJjE4rvNlgpC5HZl6SQQ5Di2C2s=";
  };
in
stdenv.mkDerivation rec {
  pname = "obs-urlsource";
  version = "0.3.7";

  src = fetchFromGitHub {
    owner = "locaal-ai";
    repo = "obs-urlsource";
    rev = version;
    sha256 = "sha256-ZWwD8jJkL1rAUeanD4iChcgpnJaC5pPo36Ot36XOSx8=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    git
  ];
  buildInputs = [
    curl
    obs-studio
    pugixml
    qtbase
  ];
  dontWrapQtApps = true;

  NIX_CFLAGS_COMPILE = [
    "-I${websocketpp}"
    "-I${asio}/asio/include"
  ];

  postPatch = ''
    # Update websocketpp configuration
    sed -i 's|URL .*|SOURCE_DIR "${websocketpp}"\n    DOWNLOAD_COMMAND ""|' cmake/FetchWebsocketpp.cmake

    # Update lexbor configuration
    sed -i \
      -e 's|GIT_REPOSITORY .*|SOURCE_DIR "${lexbor}"|' \
      -e 's|GIT_TAG .*|DOWNLOAD_COMMAND ""\n    UPDATE_COMMAND ""|' \
      cmake/BuildLexbor.cmake
  '';

  postInstall = ''
    rm -rf $out/lib/cmake
  '';

  # Verify installation
  postFixup = ''
    # Verify plugin files exist
    plugin_file="$out/lib/obs-plugins/obs-urlsource.so"
    if [ ! -f "$plugin_file" ]; then
      echo "Error: Plugin file not found at $plugin_file"
      exit 1
    fi
  '';

  cmakeFlags = [
    (lib.cmakeOptionType "string" "QT_VERSION" "6")
    (lib.cmakeOptionType "string" "CMAKE_CXX_FLAGS" "-Wno-error=deprecated-declarations")
    (lib.cmakeBool "ENABLE_QT" true)
    (lib.cmakeBool "USE_SYSTEM_CURL" true)
    (lib.cmakeBool "USE_SYSTEM_PUGIXML" true)
    (lib.cmakeBool "CMAKE_COMPILE_WARNING_AS_ERROR" false)
  ];

  passthru.updateScript = writeScript "update-${pname}" ''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p curl jq nix common-updater-scripts
    set -eu -o pipefail

    latestTag="$(curl -s https://api.github.com/repos/locaal-ai/obs-urlsource/releases/latest | jq -r .tag_name)"
    update-source-version ${pname} "$latestTag"
  '';

  meta = with lib; {
    description = "OBS plugin to fetch data from a URL or file, connect to an API or AI service, parse responses and display text, image or audio on scene";
    homepage = "https://github.com/locaal-ai/obs-urlsource";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [
      "x86_64-linux"
      "i686-linux"
    ];
  };
}
