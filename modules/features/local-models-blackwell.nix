{ self, inputs, ... }:
{
  flake.nixosModules.localModelsBlackwell =
    { pkgs, ... }:
    let
      llmPkgs = import inputs.llm-agents.inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config = pkgs.config;
      };
    in
    {
      imports = [ self.nixosModules.localModels ];

      services.local-models = {
        # Hermes and OpenCode are clients of this router, not competing backends.
        competingServices = [
          "llama-cpp.service"
        ];
        user = "capcu";
        providerName = "Local Blackwell";
        package = llmPkgs.llama-cpp.override {
          cudaSupport = true;
          cudaPackages = llmPkgs.cudaPackages_13;
        };
        # Initial tuning points, not measured winners. Hybrid P/E-core CPUs
        # need a thread sweep; using every core can slow CPU expert decoding.
        threads = 8;
        contextSize = 16384;
        flashAttention = "on";
        fitTarget = 1536;
        # First 20/40 MoE blocks keep experts on CPU; later experts use GPU.
        # llama.cpp cannot auto-fit with CPU-expert tensor overrides; the MoE
        # context must be validated against actual free VRAM separately.
        cpuExpertLayers = 20;
        # Near-full-context decode validated above 15 tok/s on 2026-10-16.
        # See local-models/BLACKWELL.md for boundary trials and memory limits.
        modelOverrides = {
          "qwen3.8-27b-abliterated" = {
            contextSize = 45056;
            name = "Qwen3.8-27B-Ablit";
            file = "Huihui-Qwen3.8-27B-abliterated-UD-DW-IQ3_S.gguf";
            hash = "d0eaa1e90e7630de8cefaf52510eb8913c76f85da0186d8f85a462aa6a40192c";
          };
          "qwen3.5-9b-abliterated" = {
            contextSize = 245760;
            name = "Qwen3.5-9B-Ablit";
            file = "Huihui-Qwen3.5-9B-abliterated.Q6_K.gguf";
            hash = "c57ef5dc56ead87f054e808c14e4edbd4be60b3a32717cc38ea54e90dc296d2c";
          };
          "qwen3.6-35b-a3b-abliterated" = {
            contextSize = 143360;
            name = "Qwen3.6-35B-MoE-Ablit";
          };
          "qwen3.8-27b-coder390-abliterated" = {
            contextSize = 45056;
            name = "Qwen3.8-27B-Coder-Ablit";
            repo = "huihui-ai/Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-GGUF";
            revision = "a0b17c71d9943529aefe88b83f494bf01c6b4d68";
            file = "Huihui-Qwen3.8-27B-Coder390-EfficientThink-abliterated-IQ3_S3.gguf";
            hash = "f2254ca70ff3d3a0319a0b8d4121b6a94d7148e4a95ce601641ed787194438a8";
            projector = "mmproj-model-bf16.gguf";
            projectorHash = "b29105bb672caed06f098997e644a2d497ee0e4f4a89011868c5e28424fefe99";
            moe = false;
          };
        };
      };
    };
}
