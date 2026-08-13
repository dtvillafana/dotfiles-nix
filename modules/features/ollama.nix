{ inputs, ... }:
{
  flake.nixosModules.ollama =
    { pkgs, ... }:
    let
      llmPkgs = import inputs.llm-agents.inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config = pkgs.config;
      };
    in
    {
      services.ollama = {
        enable = true;
        package = llmPkgs.ollama-cuda;
        environmentVariables = {
          OLLAMA_NUM_GPU = "99";
          OLLAMA_GPU_OVERHEAD = "805306368";
          OLLAMA_CONTEXT_LENGTH = "65536";
        };
        loadModels = [
          "qwen3.5:9b"
        ];
      };

      environment.systemPackages = with llmPkgs; [
        ollama-cuda
      ];
    };
}
