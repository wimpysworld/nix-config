{
  description = "Nix shell for network tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    }:

    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          bmon # Modern Unix `iftop`
          curlie # Terminal HTTP client
          dogdns # Modern Unix `dig`
          fast-cli # Terminal fast.com speedtest
          httpie # Terminal HTTP client
          iperf3 # Terminal network benchmarking
          mtr # Modern Unix `traceroute`
          netdiscover # Modern Unix `arp`
          nethogs # Modern Unix `iftop`
          ookla-speedtest # Terminal speedtest
          wavemon # Terminal WiFi monitor
        ];
      };
    });
}
