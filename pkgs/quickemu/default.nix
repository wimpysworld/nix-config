{ lib
, fetchFromGitHub
, stdenv
, makeWrapper
, qemu
, gnugrep
, gnused
, lsb-release
, jq
, procps
, python3
, cdrtools
, usbutils
, util-linux
, socat
, spice-gtk
, swtpm
, unzip
, wget
, xdg-user-dirs
, xrandr
, zsync
, OVMF
, OVMFFull
, quickemu
, testers
, installShellFiles
}:
let
  runtimePaths = [
    qemu
    gnugrep
    gnused
    jq
    lsb-release
    procps
    python3
    cdrtools
    usbutils
    util-linux
    unzip
    socat
    swtpm
    wget
    xdg-user-dirs
    xrandr
    zsync
  ];
in

stdenv.mkDerivation rec {
  pname = "quickemu";
  version = "7e3515aa063ea8ff8d1369a167059a78e9d9c2f5";

  src = fetchFromGitHub {
    owner = "quickemu-project";
    repo = "quickemu";
    rev = version;
    hash = "sha256-dr3QkbHSPxpf+2NvggNrovIqkeyqWDvrBsbFQ+r7074=";
  };

  postPatch = ''
    sed -i \
      -e '/OVMF_CODE_4M.secboot.fd/s|ovmfs=(|ovmfs=("${OVMFFull.firmware}","${OVMFFull.variables}" |' \
      -e '/OVMF_CODE_4M.fd/s|ovmfs=(|ovmfs=("${OVMF.firmware}","${OVMF.variables}" |' \
      -e '/cp "''${VARS_IN}" "''${VARS_OUT}"/a chmod +w "''${VARS_OUT}"' \
      -e 's/Icon=.*qemu.svg/Icon=qemu/' \
      quickemu
  '';

  nativeBuildInputs = [ makeWrapper installShellFiles ];

  installPhase = ''
    runHook preInstall

    installManPage docs/quickget.1 docs/quickemu.1 docs/quickemu_conf.1
    install -Dm755 -t "$out/bin" chunkcheck quickemu quickget windowskey

    # spice-gtk needs to be put in suffix so that when virtualisation.spiceUSBRedirection
    # is enabled, the wrapped spice-client-glib-usb-acl-helper is used
    for f in chunkcheck quickget quickemu windowskey; do
      wrapProgram $out/bin/$f \
        --prefix PATH : "${lib.makeBinPath runtimePaths}" \
        --suffix PATH : "${lib.makeBinPath [ spice-gtk ]}"
    done

    runHook postInstall
  '';

  passthru.tests = testers.testVersion { package = quickemu; };

  meta = with lib; {
    description = "Quickly create and run optimised Windows, macOS and Linux desktop virtual machines";
    homepage = "https://github.com/quickemu-project/quickemu";
    license = licenses.mit;
    maintainers = with maintainers; [ fedx-sudo flexiondotorg ];
  };
}
