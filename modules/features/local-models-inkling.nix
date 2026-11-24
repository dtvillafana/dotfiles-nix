{ self, ... }:
{
  flake.nixosModules.localModelsInkling =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.local-inkling;
      local = config.services.local-models;
      modelId = "inkling-2-mini-abliterated";
      revision = "ce0157864e970352f6ba33e8a781446b9b26ec99";
      model = pkgs.fetchurl {
        url = "https://huggingface.co/onemunanoyo/Inkling-2-Mini-Abliterated-Balanced-GGUF/resolve/${revision}/Inkling-2-Mini-Abliterated-Balanced-${cfg.quant}.gguf";
        sha256 = cfg.modelHash;
      };
    in
    {
      key = "dotfiles-nix-local-models-inkling";
      imports = [ self.nixosModules.localModels ];

      options.services.local-inkling = {
        package = lib.mkOption {
          type = lib.types.package;
          description = "Pinned Inkling-capable runtime with the host's CUDA toolkit.";
        };
        quant = lib.mkOption {
          type = lib.types.enum [
            "UD-Q3_K_XL"
            "UD-Q4_K_XL"
          ];
          description = "Host-selected Balanced GGUF quantization.";
        };
        modelHash = lib.mkOption {
          type = lib.types.str;
          description = "SHA-256 of the pinned GGUF.";
        };
        contextSize = lib.mkOption {
          type = lib.types.ints.between 8193 114688;
          default = 16384;
          description = "Worker and client context; includes the output budget.";
        };
        cpuExpertLayers = lib.mkOption {
          type = lib.types.listOf (lib.types.ints.between 0 23);
          description = "Physical MoE blocks with experts on CPU; reserve GPU space preferentially for the three-pass loop core.";
        };
      };

      config = {
        # Separate workers preserve the existing K2 parser/runtime and model pins.
        # Conflicts are symmetric; whichever backend is requested last owns the GPU.
        systemd.services.local-inkling = {
          description = "On-demand Inkling 2 Mini Balanced abliterated worker";
          after = [
            "network.target"
            "local-models.service"
          ]
          ++ local.competingServices;
          conflicts = [ "local-models.service" ] ++ local.competingServices;
          serviceConfig = {
            ExecStart = lib.escapeShellArgs [
              "${cfg.package}/bin/llama-server"
              "--model"
              (toString model)
              "--alias"
              modelId
              "--host"
              "127.0.0.1"
              "--port"
              "18085"
              "--ctx-size"
              (toString cfg.contextSize)
              "--parallel"
              "1"
              "--threads"
              (toString local.threads)
              "--threads-batch"
              (toString local.threads)
              "--batch-size"
              "512"
              "--ubatch-size"
              "64"
              "--n-gpu-layers"
              "99"
              "--override-tensor"
              (lib.concatStringsSep "," (
                map (layer: "^blk\\.${toString layer}\\.ffn_(gate_up|up|gate|down)_exps.*=CPU") cfg.cpuExpertLayers
              ))
              "--fit"
              "off"
              "--flash-attn"
              "on"
              "--cache-type-k"
              "f16"
              "--cache-type-v"
              "f16"
              "--jinja"
              "--reasoning-format"
              "deepseek"
              "--temp"
              "1.0"
              "--top-p"
              "1.0"
              "--top-k"
              "0"
              "--min-p"
              "0.0"
            ];
            ExecStartPost = lib.escapeShellArgs [
              "${pkgs.curl}/bin/curl"
              "--fail"
              "--silent"
              "--show-error"
              "--output"
              "/dev/null"
              "--retry"
              "180"
              "--retry-all-errors"
              "--retry-delay"
              "1"
              "--max-time"
              "1"
              "http://127.0.0.1:18085/health"
            ];
            TimeoutStartSec = 240;
            DynamicUser = true;
            StateDirectory = "local-inkling";
            WorkingDirectory = "/var/lib/local-inkling";
            Environment = "HOME=/var/lib/local-inkling";
            MemorySwapMax = 0;
            TimeoutStopSec = 60;
          };
        };

        systemd.sockets.local-inkling-proxy = {
          description = "On-demand Inkling API socket";
          wantedBy = [ "sockets.target" ];
          listenStreams = [ "127.0.0.1:18084" ];
        };
        systemd.services.local-inkling-proxy = {
          description = "Socket-activated proxy for Inkling";
          requires = [
            "local-inkling-proxy.socket"
            "local-inkling.service"
          ];
          bindsTo = [ "local-inkling.service" ];
          after = [ "local-inkling.service" ];
          serviceConfig = {
            ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:18085";
            DynamicUser = true;
          };
        };

        home-manager.users.${local.user}.opencode.settings.providers.local-inkling = {
          name = "Local Inkling (Balanced)";
          package = "@opencode/ai/providers/openai-compatible";
          settings = {
            baseURL = "http://127.0.0.1:18084/v1";
            headerTimeout = 3600000;
            chunkTimeout = 3600000;
          };
          models.${modelId} = {
            name = "Inkling 2 Mini Abliterated (${cfg.quant}, CPU/GPU)";
            capabilities = {
              tools = true;
              input = [ "text" ];
              output = [ "text" ];
            };
            compatibility.reasoningField = "reasoning_content";
            limit = {
              context = cfg.contextSize;
              output = 8192;
            };
            body = {
              temperature = 1.0;
              top_p = 1.0;
              top_k = 0;
              min_p = 0.0;
              chat_template_kwargs.reasoning_effort = "high";
            };
            cost = {
              input = 0;
              output = 0;
            };
          };
        };
      };
    };
}
