{ ... }:
{
  flake.nixosModules.ollama =
    { pkgs, ... }:
    {
      nixpkgs.config.cudaCapabilities = [
        "6.1"
      ];

      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
        environmentVariables = {
          OLLAMA_LLM_LIBRARY = "cuda";
          OLLAMA_NUM_GPU = "99";
          OLLAMA_GPU_OVERHEAD = "1717986918";
          OLLAMA_CONTEXT_LENGTH = "65536";
        };
        loadModels = [
          "qwen3.5:9b"
        ];
      };

      environment.systemPackages = with pkgs; [
        ollama-cuda
      ];
    };
}
