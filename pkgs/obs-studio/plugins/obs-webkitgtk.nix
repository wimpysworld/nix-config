{ lib
, stdenv
, fetchFromGitHub
, webkitgtk_4_1
, pkg-config
, meson
, ninja
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-webkitgtk";
  version = "unstable-2023-11-10";

  src = fetchFromGitHub {
    owner = "fzwoch";
    repo = pname;
    rev = "ddf230852c3c338e69b248bdf453a0630f1298a7";
    hash = "sha256-DU2w9dRgqWniTE76KTAtFdxIN82VKa/CS6ZdfNcTMto=";
  };

  nativeBuildInputs = [ pkg-config meson ninja ];
  buildInputs = [ webkitgtk_4_1 obs-studio ];

  postInstall = ''
    mv $out/libexec/obs-plugins/obs-webkitgtk-helper $out/lib/obs-plugins/
    rm -rf $out/libexec
  '';

  meta = with lib; {
    description = "Yet another OBS Studio browser source";
    homepage = "https://github.com/fzwoch/obs-webkitgtk";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
