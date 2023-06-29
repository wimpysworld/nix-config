{ inputs, outputs, stateVersion, username, ... }:
let
  helpers = import ./helpers.nix { inherit inputs outputs stateVersion username; };
in
{
  mkHome = helpers.mkHome;
  mkHost = helpers.mkHost;
  forAllSystems = helpers.forAllSystems;
}
