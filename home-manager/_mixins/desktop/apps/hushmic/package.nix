{
  inputs,
  lib,
  pkgs,
}:
let
  upstream = lib.attrByPath [
    "packages"
    pkgs.stdenv.hostPlatform.system
    "default"
  ] null inputs.hushmic;
in
if upstream == null then
  null
else
  upstream.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./timeshare-scheduler-test.patch ];
  })
