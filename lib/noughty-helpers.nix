# Pure helper functions for noughty system attributes.
# No module system dependency; independently testable.
{ lib }:
{
  hostName,
  userName,
  hostTags,
  userTags,
}:
{
  # Check whether the current user is in a list of usernames.
  isUser = users: lib.elem userName users;

  # Check whether the current host is in a list of hostnames.
  isHost = hosts: lib.elem hostName hosts;

  # Hostname with the first letter capitalised (e.g. "vader" → "Vader").
  hostNameCapitalised =
    (lib.strings.toUpper (builtins.substring 0 1 hostName))
    + (builtins.substring 1 (builtins.stringLength hostName) hostName);

  # Check whether the host has a specific tag.
  hostHasTag = tag: lib.elem tag hostTags;

  # Check whether the user has a specific tag.
  userHasTag = tag: lib.elem tag userTags;

  # Check whether the host has all of the listed tags.
  hostHasTags = ts: lib.all (t: lib.elem t hostTags) ts;

  # Check whether the user has all of the listed tags.
  userHasTags = ts: lib.all (t: lib.elem t userTags) ts;

  # Check whether the host has at least one of the listed tags.
  hostHasAnyTag = ts: lib.any (t: lib.elem t hostTags) ts;

  # Check whether the user has at least one of the listed tags.
  userHasAnyTag = ts: lib.any (t: lib.elem t userTags) ts;
}
