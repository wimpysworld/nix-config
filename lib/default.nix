{ inputs, outputs, stateVersion, ... }:
let
  helpers = import ./helpers.nix { inherit inputs outputs stateVersion; };
in
{
  inherit (helpers) mkHome;
  inherit (helpers) mkHost;
  inherit (helpers) forAllSystems;
}
