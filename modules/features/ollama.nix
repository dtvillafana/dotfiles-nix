{ ... }:
{
  flake.nixosModules.ollama =
    { pkgs, ... }:
    {
      services.ollama = {
        enable = true;
        acceleration = "cuda";
        loadModels = [
          "qwen3.5:9b"
        ];
      };

      environment.systemPackages = with pkgs; [
        ollama
      ];
    };
}
