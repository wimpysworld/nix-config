{ stdenv, lib, fetchFromGitLab, pkg-config, libfprint, libfprint-tod, gusb, udev, nss, openssl, meson, pixman, python3, ninja, glib }:
stdenv.mkDerivation {
  pname = "libfprint-2-tod1-vfs009a";
  version = "0.8.5";

  src = fetchFromGitLab {
    domain = "gitlab.com";
    owner = "bingch";
    repo = "libfprint-tod-vfs0090";
    rev = "3a5e27bc4e5dbbb42b953958796830e87b82d843";
    sha256 = "sha256-s6YPBeUYWBRUpVAsBvCKKTGQ8juMbPuJYWzXxKpcJkk=";
  };

  patches = [
    # TODO remove once https://gitlab.freedesktop.org/3v1n0/libfprint-tod-vfs0090/-/merge_requests/1 is merged
    ./0001-vfs0090-add-missing-explicit-dependencies-in-meson.b.patch
    # TODO remove once https://gitlab.freedesktop.org/3v1n0/libfprint-tod-vfs0090/-/merge_requests/2 is merged
    ./0002-vfs0090-add-missing-linux-limits.h-include.patch
  ];

  nativeBuildInputs = [ pkg-config meson ninja ];
  buildInputs = [ libfprint libfprint-tod glib gusb udev nss openssl pixman python3 ];

  installPhase = ''
    runHook preInstall

    install -D -t "$out/lib/libfprint-2/tod-1/" libfprint-tod-vfs009x.so
    install -D -t "$out/lib/udev/rules.d/" $src/60-libfprint-2-tod-vfs0090.rules

    runHook postInstall
  '';

  passthru.driverPath = "/lib/libfprint-2/tod-1";

  meta = with lib; {
    description = "A libfprint-2-tod Touch OEM Driver for Synaptics Sensor 06cb:009a";
    homepage = "https://gitlab.com/bingch/libfprint-tod-vfs0090";
    license = licenses.lgpl21Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ flexiondotorg ];
  };
}
