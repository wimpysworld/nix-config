# Patched build of the upstream Fresh editor (from the `fresh` flake input).
#
# The wrapper takes the upstream derivation as `fresh-upstream` (passed in
# from `overlays/default.nix`, which is where flake inputs are visible) and
# layers our theme-key-resolution patch on top via `overrideAttrs`.
#
# Once https://github.com/sinelaw/fresh PR for the missing `ui.*` keys lands
# upstream, this wrapper can be dropped and the mixin pointed back at
# `inputs.fresh.packages.${system}.fresh` directly.
{ fresh-upstream }:

fresh-upstream.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ../patches/fresh-fix-theme-key-resolution.patch
  ];
})
