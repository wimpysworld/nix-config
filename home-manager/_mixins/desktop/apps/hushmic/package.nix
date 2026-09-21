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
    # The patched test inherits SCHED_IDLE from the local Nix builder, while the upstream builder provides SCHED_OTHER.
    # It accepts SCHED_BATCH as another Linux non-realtime policy. A panic closure rejects every HushMic scheduler request.
    patches = (oldAttrs.patches or [ ]) ++ [ ./timeshare-scheduler-test.patch ];
  })
