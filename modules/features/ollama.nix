{ ... }:
{
  flake.nixosModules.ollama =
    { pkgs, ... }:
    {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
        environmentVariables = {
          OLLAMA_NUM_GPU = "99";
          OLLAMA_GPU_OVERHEAD = "805306368";
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
