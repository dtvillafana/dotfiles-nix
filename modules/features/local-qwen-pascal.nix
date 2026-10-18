{ self, ... }:
{
  flake.nixosModules.localQwenPascal = {
    imports = [ self.nixosModules.localQwen ];

    services.local-qwen = {
      # Keep desktop headroom while testing real agent workloads.
      cpuExpertLayers = 35;
      # Per-host tuning; keep the Blackwell profile and shared defaults separate.
      modelOverrides = {
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
