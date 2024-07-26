{ hostname, ... }:
{
  nix.settings.cores =
    if hostname == "phasma" then
      18
    else if hostname == "vader" then
      24
    else
      0;
}
