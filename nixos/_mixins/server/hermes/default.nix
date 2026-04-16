{
  config,
  inputs,
  lib,
  noughtyLib,
  ...
}:
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  config = lib.mkIf (noughtyLib.hostHasTag "hermes") {
  };
}
