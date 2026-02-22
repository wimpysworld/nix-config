{
  darwinStateVersion,
  inputs,
  outputs,
  stateVersion,
  users ? { },
  ...
}:
let
  builders = import ./flake-builders.nix {
    inherit
      darwinStateVersion
      inputs
      outputs
      stateVersion
      users
      ;
  };
in
{
  inherit (builders)
    mkDarwin
    mkHome
    mkNixos
    forAllSystems
    mkSystemConfig
    generateConfigs
    isLinuxEntry
    isDarwinEntry
    isISOEntry
    isHomeOnlyEntry
    mkAllNixos
    mkAllDarwin
    mkAllHomes
    mkPackages
    mkDevShells
    ;
}
