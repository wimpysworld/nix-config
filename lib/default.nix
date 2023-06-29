{ inputs, outputs, stateVersion, ... }:
let
  helpers = import ./helpers.nix { inherit inputs outputs stateVersion; };
in
{
  mkHome = helpers.mkHome;
  mkHost = helpers.mkHost;
  forAllSystems = helpers.forAllSystems;
}
