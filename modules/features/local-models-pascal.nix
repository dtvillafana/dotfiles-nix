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
          inherit (inputs) llama-cpp-k2-src llama-cpp-k2-parser-fix;
          llama-cpp = llmPkgs.llama-cpp.override {
            cudaSupport = true;
            cudaPackages = llmPkgs.cudaPackages_12;
          };
        };
        # Keep desktop headroom while testing real agent workloads.
        cpuExpertLayers = 35;
        # Per-host tuning; keep the Blackwell profile and shared defaults separate.
        modelOverrides = {
          # Most-downloaded matching abliterated GGUF on 2026-10-18 (9,345/month).
          "k2-horizon-7b-abliterated" = {
            name = "K2 Horizon 7B Heretic Abliterated (dense, experimental)";
            repo = "mradermacher/K2-Horizon-7B-heretic-i1-GGUF";
            revision = "eeebbdece06eef115157fecc876def53b491fdb1";
            file = "K2-Horizon-7B-heretic.i1-Q4_K_M.gguf";
            hash = "303af04f5ccaa0747988902e9f712f1f452416718d7e8cc52634c97cf17266d9";
            moe = false;
            # Fit layers automatically, preserving desktop headroom and context.
            contextSize = 16384;
            fitTarget = 2304;
            logVerbosity = 4;
            # Full source template passed text, tool call, and tool-result checks.
            chatTemplate = inputs.k2-horizon-7b-chat-template.outPath;
            requestBody = {
              temperature = 1.0;
              top_p = 0.95;
              chat_template_kwargs.reasoning_effort = "high";
            };
          };
          # Most-downloaded matching abliterated GGUF on 2026-10-18 (10,696/month).
          "k2-horizon-mova-36b-a4b-abliterated" = {
            name = "K2 Horizon MoVA 36B-A4B Abliterated (MoE, experimental)";
            repo = "mradermacher/K2-Horizon-MoVA-36B-A4B-uncensored-i1-GGUF";
            revision = "e1fd59b477893da19b714d8ba5a3a221aeb82e2c";
            file = "K2-Horizon-MoVA-36B-A4B-uncensored.i1-Q4_K_M.gguf";
            hash = "264c7429d9ffbd2842c5dd2da6bd18d9f3948b8e010f3c7dc47761ea0077e591";
            moe = true;
            # Accepted 32K profile: FFN experts in RAM, dense layers on GPU.
            cpuExpertLayers = null;
            contextSize = 32768;
            # CPU overrides disable fitting; keep the measured explicit split.
            gpuLayers = 49;
            # K2 value experts are not matched by --cpu-moe. Keep blocks 3..26
            # on CPU (24 expert-bearing blocks), the remaining value experts on GPU.
            tensorOverrides = [
              "^blk\\.(3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26)\\.attn_v_exps\\.weight=CPU"
            ];
            flashAttention = "on";
            cacheTypeK = "q4_0";
            cacheTypeV = "q4_0";
            logVerbosity = 4;
            requestBody = {
              temperature = 1.0;
              top_p = 0.95;
              # Low effort emitted unparsed tool markup in the agent comparison.
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
