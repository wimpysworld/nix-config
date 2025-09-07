{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "wolfictl";
  version = "0.37.4";

  src = fetchurl (
    let
      # Determine system and architecture
      currentSystem = stdenv.hostPlatform.parsed.kernel.name; # "linux", "darwin"
      currentArch = stdenv.hostPlatform.parsed.cpu.name; # "x86_64", "aarch64"
      # Map Nix architecture names to suffixes used in the URL
      archSuffix =
        if currentArch == "aarch64" then
          "arm64"
        else if currentArch == "x86_64" then
          "amd64"
        else
          throw "chainctl: Unsupported architecture: ${currentArch}";

      # SHA256 sums from the release checksums.txt
      # https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_checksums.txt
      sha256s = {
        "darwin_amd64" = "33b55966a1486ba40317bf1cdda76e40f375390ca2652b7dec8f7a8e5df5b0d2";
        "darwin_arm64" = "019abd8cbc7c4c025580e4579e13e294c5581871e2cf302640dd06e2edf468f3";
        "linux_amd64" = "495717e7525493fa727f462832f1854be1bdd10cb6546bde7a2a1ccee8a935e3";
        "linux_arm64" = "801aef31becb9beb9549dede820a91f050f8e6ae88406c2e0396863a47dfa99f";
      };
      platformKey = "${currentSystem}_${archSuffix}";
    in
    {
      url = "https://github.com/wolfi-dev/wolfictl/releases/download/v${version}/wolfictl_${currentSystem}_${archSuffix}_${version}_${currentSystem}_${archSuffix}";
      # Look up the SHA256 sum; throw an error if not found for the current platform
      sha256 =
        sha256s.${platformKey} or (throw "wolfictl: SHA256 sum not available for platform ${platformKey}");
    }
  );

  # We are fetching a single binary file
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/wolfictl
    runHook postInstall
  '';

  meta = with lib; {
    description = "A CLI used to work with the Wolfi OSS project";
    homepage = "https://github.com/wolfi-dev/wolfictl";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
  };
}
