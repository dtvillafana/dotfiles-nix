{ self, inputs, ... }:
{
  flake.nixosModules.localModelsPascal =
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
        package = pkgs.callPackage ../../packages/llama-cpp-k2.nix {
          inherit (inputs) llama-cpp-k2-src;
          llama-cpp = llmPkgs.llama-cpp.override {
            cudaSupport = true;
            cudaPackages = llmPkgs.cudaPackages_12;
          };
        };
        # Keep desktop headroom while testing real agent workloads.
        cpuExpertLayers = 35;
        # Per-host tuning; keep the Blackwell profile and shared defaults separate.
        modelOverrides = {
          # Most-downloaded matching abliterated GGUF on 2026-10-18 (10,696/month).
          "k2-horizon-mova-36b-a4b-abliterated" = {
            name = "K2 Horizon MoVA 36B-A4B Abliterated (MoE, experimental)";
            repo = "mradermacher/K2-Horizon-MoVA-36B-A4B-uncensored-i1-GGUF";
            revision = "e1fd59b477893da19b714d8ba5a3a221aeb82e2c";
            file = "K2-Horizon-MoVA-36B-A4B-uncensored.i1-Q4_K_M.gguf";
            hash = "264c7429d9ffbd2842c5dd2da6bd18d9f3948b8e010f3c7dc47761ea0077e591";
            moe = true;
            # Start conservatively: all experts in RAM, modest unvalidated context.
            cpuExpertLayers = null;
            contextSize = 16384;
            requestBody = {
              temperature = 1.0;
              top_p = 0.95;
              chat_template_kwargs.reasoning_effort = "high";
            };
          };
          # Agentic trials use extra fitting headroom for the live desktop.
          "qwen3.5-9b-abliterated" = {
            contextSize = 16384;
            fitTarget = 2304;
            logVerbosity = 4;
            # Compare the deployed sampler against the greedy pilot's repair loop.
            requestBody.temperature = 1.0;
            requestBody.chat_template_kwargs.enable_thinking = false;
          };
          # Keep starting 64K context; placement is a nonqualifying safe fallback.
          "qwen3.6-35b-a3b-abliterated" = {
            contextSize = 65536;
            flashAttention = "on";
            cacheTypeK = "q8_0";
            cacheTypeV = "q8_0";
            logVerbosity = 4;
            requestBody.temperature = 0.0;
          };
          "qwen3.8-27b-abliterated" = {
            contextSize = 32768;
            logVerbosity = 4;
            # Mixed attention/FFN placement trial; verify real allocation at load.
            gpuLayers = 36;
            cpuFfnLayers = 60;
            # This model's template otherwise defaults to xhigh reasoning.
            requestBody.chat_template_kwargs.reasoning_effort = "low";
            requestBody.chat_template_kwargs.enable_thinking = false;
            requestBody.temperature = 0.0;
          };
        };
      };
    };
}
