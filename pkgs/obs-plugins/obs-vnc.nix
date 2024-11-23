{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, pkg-config
, libvncserver
}:

stdenv.mkDerivation rec {
  pname = "obs-vnc";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "norihiro";
    repo = "obs-vnc";
    rev = version;
    sha256 = "sha256-eTvKACeVFFw6DOFAiWaG/m14jYyzZc61e79S8oVWrCs=";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ libvncserver obs-studio ];

  postInstall = ''
    mkdir $out/lib $out/share
    mv $out/obs-plugins/64bit $out/lib/obs-plugins
    rm -rf $out/obs-plugins
    mv $out/data $out/share/obs
  '';

  meta = with lib; {
    description = "VNC viewer integrated into OBS Studio as a source plugin";
    homepage = "https://github.com/norihiro/obs-vnc";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
