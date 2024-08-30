{
  inputs,
  outputs,
  stateVersion,
  ...
}:
let
  helpers = import ./helpers.nix { inherit inputs outputs stateVersion; };
in
{
  inherit (helpers)
    mkDarwin
    mkHome
    mkNixos
    forAllSystems
    ;
}
