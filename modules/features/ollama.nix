{ inputs, ... }:
{
  flake.nixosModules.ollama =
    { pkgs, ... }:
    let
      llmPkgs = import inputs.llm-agents.inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config = pkgs.config;
      };
      ollama = llmPkgs.ollama-cuda.overrideAttrs (old: rec {
        version = "0.32.9";
        src = inputs.ollama-src;
        vendorHash = "sha256-HMwoaFBMbpoy8f0I+O+i7kIa9BslLu3FcVWeaIOkpvs=";
        llamaCppVersion = "b10353";
        llamaCppSrc = llmPkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = llamaCppVersion;
          hash = "sha256-MQP91lL8zQLYcnYw5GlkMvH5sXiES+C6L4/1G3Y6TPY=";
        };
        postPatch =
          builtins.replaceStrings
            [
              "${old.passthru.llamaCppSrc}"
              old.passthru.llamaCppVersion
              "cmake/apply-git-patches.cmake"
            ]
            [
              "${llamaCppSrc}"
              llamaCppVersion
              "llama/compat/apply-patch.cmake"
            ]
            old.postPatch;
        passthru = old.passthru // {
          inherit llamaCppSrc llamaCppVersion;
        };
      });
    in
    {
      services.ollama = {
        enable = true;
        package = ollama;
        environmentVariables = {
          OLLAMA_NUM_GPU = "99";
          OLLAMA_GPU_OVERHEAD = "805306368";
          OLLAMA_CONTEXT_LENGTH = "65536";
        };
        loadModels = [
          "qwen3.5:9b"
        ];
      };

      environment.systemPackages = [ ollama ];
    };
}
