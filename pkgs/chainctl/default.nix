{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "chainctl";
  version = "0.2.88";

  src = fetchurl (
    let
      # Determine system and architecture
      currentSystem = stdenv.hostPlatform.parsed.kernel.name; # "linux", "darwin"
      currentArch = stdenv.hostPlatform.parsed.cpu.name;      # "x86_64", "aarch64"
      # Map Nix architecture names to suffixes used in the URL
      archSuffix =
        if currentArch == "aarch64" then
          "arm64"
        else if currentArch == "x86_64" then
          "x86_64"
        else
          throw "chainctl: Unsupported architecture: ${currentArch}";

      # SHA256 sums derived from the Homebrew formula
      # https://github.com/chainguard-dev/homebrew-tap/blob/main/Formula/chainctl.rb
      sha256s = {
        "darwin_x86_64" = "9692dad7b6cb00c11a7dd22cf1de5d11a1cbf73ed69ea252598be55e5beb5851";
        "darwin_arm64" = "0a5be77a442f0aa5aa87bab6f486bd89faa9b4795f1567f592025c1e30c2604a";
        "linux_x86_64" = "8d4094c8dc7b09af5ae6080194d1ad39363d4aba009b8d5752bad807b0b35461";
        "linux_arm64" = "689901c0c7c79aff2ca520549b2d830368ec5e3e103306d65fc9374d750637c3";
      };
      platformKey = "${currentSystem}_${archSuffix}";
    in
    {
      url = "https://dl.enforce.dev/chainctl/${version}/chainctl_${currentSystem}_${archSuffix}";
      # Look up the SHA256 sum; throw an error if not found for the current platform
      sha256 =
        sha256s.${platformKey} or (throw "chainctl: SHA256 sum not available for platform ${platformKey}");
    }
  );

  # We are fetching a single binary file
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/chainctl
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI for the Chainguard Platform";
    homepage = "https://chainguard.dev";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
  };
}
