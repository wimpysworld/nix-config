{ inputs, outputs, stateVersion, ... }:
let
  helpers = import ./helpers.nix { inherit inputs outputs stateVersion; };
in
{
  inherit (helpers) mkHome mkHost forAllSystems;
}
