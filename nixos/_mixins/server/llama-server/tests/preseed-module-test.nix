{ lib }:
let
  evalFor =
    hostTags:
    lib.evalModules {
      modules = [
        {
          options = {
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
            systemd = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
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
  minVramMessage = "llama-server inference hosts require at least 16 GiB of configured compute VRAM.";
  hasAssertion = message: assertions: lib.any (assertion: assertion.message == message) assertions;
in
assert hasAssertion preseedMessage inferenceEval.config.assertions;
assert hasAssertion minVramMessage inferenceEval.config.assertions;
assert !(hasAssertion preseedMessage nonInferenceEval.config.assertions);
assert !(hasAssertion minVramMessage nonInferenceEval.config.assertions);
true
