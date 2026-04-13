{ lib }:
let
  flake = builtins.getFlake (toString ../../../../../.);
  nixpkgs = flake.inputs.nixpkgs;

  evalFor =
    hostTags:
    hostVramGiB:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../../../../../lib/noughty
        {
          system.stateVersion = "25.11";
          noughty.host = {
            name = "testhost";
            kind = "computer";
            platform = "x86_64-linux";
            gpu.compute.vram = hostVramGiB;
            tags = hostTags;
          };
        }
        ../preseed.nix
      ];
    };

  inferenceEval = evalFor [ "inference" ] 96;
  nonInferenceEval = evalFor [ ] 96;
  service = inferenceEval.config.systemd.services.llama-models-preseed;
  assertionMessages = map (assertion: assertion.message) inferenceEval.config.assertions;
in
assert inferenceEval.config.systemd.services ? llama-models-preseed;
assert !(nonInferenceEval.config.systemd.services ? llama-models-preseed);
assert service.serviceConfig.Type == "oneshot";
assert service.serviceConfig.User == "root";
assert builtins.elem "network-online.target" service.after;
assert builtins.elem "network-online.target" service.wants;
assert service.environment.LLAMA_PRESEED_CACHE_ROOT == "/var/lib/llama-models/huggingface";
assert service.environment.HF_HOME == "/var/lib/llama-models/huggingface";
assert service.environment.HF_HUB_CACHE == "/var/lib/llama-models/huggingface/hub";
assert builtins.elem "llama-server preseed requires a non-empty selected model set." assertionMessages;
assert builtins.any (message: lib.hasPrefix "llama-server preseed is missing model metadata for:" message) assertionMessages;
true
