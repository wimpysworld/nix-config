{ lib, username, ... }:
{
  imports = lib.optional (builtins.pathExists (./. + "/${username}")) ./${username};
}
