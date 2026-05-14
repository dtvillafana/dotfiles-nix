{ ... }:
{
  flake.nixosModules.ollama =
    { pkgs, ... }:
    {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
        loadModels = [
          "qwen3.5:9b"
        ];
      };

      environment.systemPackages = with pkgs; [
        ollama-cuda
      ];
    };
}
