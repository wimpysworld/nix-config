{ lib
, stdenv
, fetchFromGitHub
, cmake
, git
, obs-studio
, pugixml
, curl
, qtbase
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

  # Also need asio
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

  nativeBuildInputs = [ cmake git ];
  buildInputs = [ curl obs-studio pugixml qtbase ];
  dontWrapQtApps = true;

  NIX_CFLAGS_COMPILE = [
    "-I${websocketpp}"
    "-I${asio}/asio/include"
  ];

  preConfigure = ''
    # Create FetchWebsocketpp.cmake
    cat > cmake/FetchWebsocketpp.cmake << EOF
    include(FetchContent)

    # Setup websocketpp
    add_library(websocketpp INTERFACE)
    target_include_directories(websocketpp INTERFACE "${websocketpp}")
    add_library(websocketpp::websocketpp ALIAS websocketpp)

    # Setup asio
    add_library(asio INTERFACE)
    target_include_directories(asio INTERFACE
      "${asio}/asio/include"
    )

    FetchContent_Declare(
      websocketpp
      SOURCE_DIR "${websocketpp}"
      DOWNLOAD_COMMAND ""
    )

    FetchContent_Declare(
      asio
      SOURCE_DIR "${asio}"
      DOWNLOAD_COMMAND ""
    )

    FetchContent_MakeAvailable(websocketpp asio)
    EOF

    # Create BuildLexbor.cmake
    cat > cmake/BuildLexbor.cmake << 'EOF'
    include(ExternalProject)

    if(APPLE)
      set(LEXBOR_CMAKE_PLATFORM_OPTIONS -DCMAKE_OSX_ARCHITECTURES=x86_64$<SEMICOLON>arm64)
    else()
      if(WIN32)
        add_compile_definitions(LEXBOR_STATIC=1)
        set(LEXBOR_CMAKE_PLATFORM_OPTIONS "-DCMAKE_C_FLAGS=/W3 /utf-8 /MP" "-DCMAKE_CXX_FLAGS=/W3 /utf-8 /MP")
      else()
        set(LEXBOR_CMAKE_PLATFORM_OPTIONS -DCMAKE_SYSTEM_NAME=Linux)
      endif()
    endif()

    set(lexbor_lib_filename "''${CMAKE_STATIC_LIBRARY_PREFIX}lexbor_static''${CMAKE_STATIC_LIBRARY_SUFFIX}")

    ExternalProject_Add(
      lexbor_build
      SOURCE_DIR "@lexbor@"
      DOWNLOAD_COMMAND ""
      UPDATE_COMMAND ""
      CMAKE_GENERATOR "''${CMAKE_GENERATOR}"
      BUILD_BYPRODUCTS <INSTALL_DIR>/lib/''${lexbor_lib_filename} INSTALL_BYPRODUCTS <INSTALL_DIR>/include
      CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
                 -DLEXBOR_BUILD_SHARED=OFF
                 -DLEXBOR_BUILD_STATIC=ON
                 -DLEXBOR_BUILD_TESTS_CPP=OFF
                 -DCMAKE_BUILD_TYPE=''${CMAKE_BUILD_TYPE}
                 -DCMAKE_CXX_COMPILER=''${CMAKE_CXX_COMPILER}
                 -DCMAKE_C_COMPILER=''${CMAKE_C_COMPILER}
                 -DCMAKE_LINKER=''${CMAKE_LINKER}
                 -DCMAKE_INSTALL_MESSAGE=NEVER
                 ''${LEXBOR_CMAKE_PLATFORM_OPTIONS})

    ExternalProject_Get_Property(lexbor_build INSTALL_DIR)
    set(lexbor_lib_location "''${INSTALL_DIR}/lib/''${lexbor_lib_filename}")
    add_library(lexbor_internal STATIC IMPORTED)
    add_dependencies(lexbor_internal lexbor_build)
    set_target_properties(lexbor_internal PROPERTIES IMPORTED_LOCATION "''${lexbor_lib_location}")
    target_include_directories(lexbor_internal INTERFACE "''${INSTALL_DIR}/include")

    add_library(liblexbor_internal INTERFACE)
    add_dependencies(liblexbor_internal lexbor_internal lexbor_build)
    target_link_libraries(liblexbor_internal INTERFACE lexbor_internal)
    EOF

    substituteInPlace cmake/BuildLexbor.cmake \
      --subst-var-by lexbor ${lexbor}
  '';

  cmakeFlags = [
    (lib.cmakeOptionType "string" "QT_VERSION" "6")
    (lib.cmakeOptionType "string" "CMAKE_CXX_FLAGS" "-Wno-error=deprecated-declarations")
    (lib.cmakeBool "ENABLE_QT" true)
    (lib.cmakeBool "USE_SYSTEM_CURL" true)
    (lib.cmakeBool "USE_SYSTEM_PUGIXML" true)
    (lib.cmakeBool "CMAKE_COMPILE_WARNING_AS_ERROR" false)
  ];

  meta = with lib; {
    description = "OBS plugin to fetch data from a URL or file, connect to an API or AI service, parse responses and display text, image or audio on scene";
    homepage = "https://github.com/locaal-ai/obs-urlsource";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
