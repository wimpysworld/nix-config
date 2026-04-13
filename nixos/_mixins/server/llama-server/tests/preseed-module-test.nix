{ lib }:
let
  evalFor =
    hostTags:
    lib.evalModules {
      modules = [
        {
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.anything;
            default = [ ];
          };
        }
        ../../../../../lib/noughty
        {
          noughty.host = {
            name = "testhost";
            kind = "computer";
            platform = "x86_64-linux";
            gpu.compute.vram = 16;
            tags = hostTags;
          };
        }
        ../preseed.nix
      ];
    };

  inferenceEval = evalFor [ "inference" ];
  nonInferenceEval = evalFor [ ];
  preseedMessage = "llama-server preseed requires a non-empty selected model set.";
  hasPreseedAssertion = assertions: lib.any (assertion: assertion.message == preseedMessage) assertions;
in
assert hasPreseedAssertion inferenceEval.config.assertions;
assert !(hasPreseedAssertion nonInferenceEval.config.assertions);
true
