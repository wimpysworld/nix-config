{ lib
, stdenv
, fetchFromGitHub
, fontconfig
, gd
, glib
, harfbuzz
, libX11
, libXext
, libXft
, ncurses
, pkg-config
}:

stdenv.mkDerivation rec {
  pname = "st";
  version = "unstable=2024-03-24";

  src = fetchFromGitHub {
    owner = "siduck76";
    repo = "st";
    rev = "bddc8b04d690887ea6f8da6ff9aee7f9785e7e84";
    hash = "sha256-LIQcYcsdFSx8wdnWO59LIO+n+oqZcDSX+i6pgTJ/PXY=";
  };

  nativeBuildInputs = [
    pkg-config
  ];
  buildInputs = [
    fontconfig
    gd
    glib
    harfbuzz
    libX11
    libXext
    libXft
    ncurses
  ];

  installPhase = ''
    runHook preInstall

    TERMINFO=$out/share/terminfo make install PREFIX=$out

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/siduck76/st";
    description = "Fork of st with many add-ons";
    license = licenses.mit;
    maintainers = with maintainers; [ AndersonTorres ];
    platforms = platforms.linux;
  };
}
