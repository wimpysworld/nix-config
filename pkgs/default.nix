# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs:
let
  isCI = builtins.getEnv "CI" == "true";
in
{
  # Local packages being prepped for upstreaming
  davinci-resolve = pkgs.callPackage ./davinci-resolve { };
  defold = pkgs.callPackage ./defold { };
  defold-bob = pkgs.callPackage ./defold-bob { };
  defold-gdc = pkgs.callPackage ./defold-gdc { };
  heynote = pkgs.callPackage ./heynote { };
  jan = pkgs.callPackage ./jan { };
  station = pkgs.callPackage ./station { };
  nerd-font-patcher = pkgs.callPackage ./nerd-font-patcher { };
  local-fonts = pkgs.recurseIntoAttrs (pkgs.callPackage ./fonts { });
  local-obs = pkgs.recurseIntoAttrs (pkgs.callPackage ./obs-plugins { });

  # Local packages to prevent unintended upgrades or carrying patches
  gotosocial = pkgs.callPackage ./gotosocial { };
  owncast = pkgs.callPackage ./owncast { };

  # Non-redistributable packages - only evaluated outside CI
  cider = if !isCI then pkgs.callPackage ./cider { } else {};
  pico8 = if !isCI then pkgs.callPackage ./pico8 { } else {};
}
