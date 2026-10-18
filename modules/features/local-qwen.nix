{ inputs, ... }:
{
  flake.nixosModules.localQwen =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.local-qwen;
      llmPkgs = import inputs.llm-agents.inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config = pkgs.config;
      };
      # Same locked runtime as Nemotron: AVX2 dispatch and CUDA 12 for Pascal.
      llama = llmPkgs.llama-cpp.override {
        cudaSupport = true;
        cudaPackages = llmPkgs.cudaPackages_12;
      };
      competingServices = [
        "llama-cpp.service"
      ];
      models = lib.recursiveUpdate {
        "qwen3.8-27b-abliterated" = {
          name = "Qwen3.8 27B Abliterated (quality, CPU/GPU)";
          repo = "huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF";
          revision = "1c69098e9c32db6dc06fc48f1d6cc75ad07da89e";
          file = "Huihui-Qwen3.8-27B-abliterated-UD-DW-Q4_K_M.gguf";
          hash = "0c7cfe3060493485bb9a6a51195897b0c1d347a49929206adb9a52170183ea03";
          projector = "mmproj-model-bf16.gguf";
          projectorHash = "c9a09064683620bea3d3bfed5d4462e1a97a7d2fff7e5045d6862a0a85eeb5b5";
          moe = false;
        };
        "qwen3.6-35b-a3b-abliterated" = {
          name = "Qwen3.6 35B-A3B Abliterated (MoE, RAM experts)";
          repo = "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF";
          revision = "acd5abe0c5ebd064f3863ca7d4bba2d924ec6544";
          file = "Huihui-Qwen3.6-35B-A3B-abliterated-ggml-model-Q4_K.gguf";
          hash = "63b75afb4b68fc61059c78115b580037074de88146e0762f4a496081e410cf81";
          projector = "mmproj-model-f16.gguf";
          projectorHash = "41578def81dbfd5c193f3b4633f9ab45e3c85f116442d6b2025464082f201d6d";
          moe = true;
        };
        "qwen3.5-9b-abliterated" = {
          name = "Qwen3.5 9B Abliterated (interactive)";
          repo = "mradermacher/Huihui-Qwen3.5-9B-abliterated-GGUF";
          revision = "9f646d7eda193ddf2348134f3bff3d49eed7a2c6";
          file = "Huihui-Qwen3.5-9B-abliterated.Q4_K_M.gguf";
          hash = "ea1858ef4dc4b648b8dbb44612962a0333e945060dd0545ac0f28d7c4416e4b3";
          projector = "Huihui-Qwen3.5-9B-abliterated.mmproj-f16.gguf";
          projectorHash = "56f07ff42fc9ab24fc06a93dce5a48fb2dbe08bff1a1c6e519d50af450820148";
          moe = false;
        };
      } cfg.modelOverrides;
      contextSizeFor =
        name: models.${name}.contextSize or (cfg.modelContextSizes.${name} or cfg.contextSize);
      fetch =
        model: file: hash:
        pkgs.fetchurl {
          url = "https://huggingface.co/${model.repo}/resolve/${model.revision}/${file}";
          sha256 = hash;
        };
      presets = pkgs.writeText "local-qwen.ini" (
        lib.generators.toINI { } (
          {
            "*" = {
              ctx-size = cfg.contextSize;
              parallel = 1;
              threads = cfg.threads;
              threads-batch = cfg.threads;
              batch-size = 512;
              ubatch-size = 64;
              # Fit model layers, not a silently smaller context. CPU weights
              # remain memory mapped in system RAM; no GPU oversubscription.
              gpu-layers = "auto";
              fit = "on";
              fit-ctx = cfg.contextSize;
              fit-target = cfg.fitTarget;
              flash-attn = cfg.flashAttention;
              cache-type-k = "f16";
              cache-type-v = "f16";
              cache-ram = 0;
              ctx-checkpoints = 0;
              # The fitter does not budget all transient vision allocations.
              # Keep the encoder and its scratch buffers in system RAM.
              mmproj-offload = 0;
              image-max-tokens = 1024;
              jinja = 1;
              reasoning-format = "deepseek";
              temp = "1.0";
              top-p = "0.95";
              top-k = 20;
              min-p = 0;
              repeat-penalty = "1.0";
            };
          }
          // lib.mapAttrs (
            name: model:
            {
              ctx-size = contextSizeFor name;
              fit-ctx = contextSizeFor name;
              fit-target = model.fitTarget or cfg.fitTarget;
              log-verbosity = model.logVerbosity or 3;
              flash-attn = model.flashAttention or cfg.flashAttention;
              cache-type-k = model.cacheTypeK or "f16";
              cache-type-v = model.cacheTypeV or "f16";
              model = toString (fetch model model.file model.hash);
              mmproj = toString (fetch model model.projector model.projectorHash);
            }
            // lib.optionalAttrs (model ? gpuLayers) {
              # Explicit placement trials must not be silently refitted.
              gpu-layers = model.gpuLayers;
              fit = "off";
            }
            // lib.optionalAttrs (model ? cpuFfnLayers) {
              n-cpu-ffn = model.cpuFfnLayers;
            }
            // lib.optionalAttrs model.moe (
              if cfg.cpuExpertLayers == null then { cpu-moe = 1; } else { n-cpu-moe = cfg.cpuExpertLayers; }
            )
          ) models
        )
      );
    in
    {
      key = "dotfiles-nix-local-qwen";

      options.services.local-qwen = {
        competingServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = competingServices;
          description = "Services stopped before this router starts; exclude clients using this backend.";
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = "vir";
          description = "Home Manager user receiving the local provider and unload alias.";
        };
        providerName = lib.mkOption {
          type = lib.types.str;
          default = "Local Qwen (GTX 1070 + RAM)";
          description = "Display name for the local OpenCode provider.";
        };
        package = lib.mkOption {
          type = lib.types.package;
          default = llama;
          description = "CUDA-enabled llama.cpp runtime; select a toolkit compatible with the GPU.";
        };
        threads = lib.mkOption {
          type = lib.types.ints.positive;
          default = 6;
          description = "CPU generation and batch threads, including CPU experts.";
        };
        fitTarget = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1536;
          description = "GPU fitting headroom in MiB relative to available VRAM.";
        };
        flashAttention = lib.mkOption {
          type = lib.types.enum [
            "off"
            "on"
            "auto"
          ];
          default = "off";
          description = "Flash attention policy for this GPU/runtime.";
        };
        modelOverrides = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          default = { };
          description = "Recursive model metadata overrides and additional pinned model definitions; contextSize, flashAttention, cacheTypeK, cacheTypeV, and fitTarget override shared runtime defaults per model. gpuLayers sets explicit placement without automatic fitting, cpuFfnLayers keeps the first N dense FFN layers on CPU, logVerbosity controls diagnostics, and requestBody adds per-model OpenCode request fields.";
        };
        contextSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = 32768;
          description = "Fallback context for models without a modelContextSizes override, shared with OpenCode.";
        };
        modelContextSizes = lib.mkOption {
          type = lib.types.attrsOf (lib.types.ints.between 8193 262144);
          default = { };
          description = "Per-model context overrides, shared by llama.cpp fitting and OpenCode model limits; modelOverrides contextSize takes precedence.";
        };
        cpuExpertLayers = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between 0 40);
          default = null;
          description = ''
            Qwen3.6 MoE blocks whose experts stay on CPU in system RAM.
            Null keeps all routed experts on CPU. Lower counts consume more
            VRAM. llama.cpp may skip automatic fitting when expert tensor
            overrides are set; validate context/cache memory on the hardware.
          '';
        };
      };

      config = {
        # Historical conservative fallbacks; host profiles select measured
        # operating points. Agentic task quality is evaluated separately.
        services.local-qwen.modelContextSizes = {
          "qwen3.5-9b-abliterated" = lib.mkDefault 30720;
          "qwen3.6-35b-a3b-abliterated" = lib.mkDefault 24576;
        };

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "local-qwen-check" ''
            exec ${pkgs.python3}/bin/python3 ${./local-qwen/check.py} "$@"
          '')
          (pkgs.writeShellScriptBin "local-qwen-bench" ''
            exec ${pkgs.python3}/bin/python3 ${./local-qwen/benchmark.py} "$@"
          '')
        ];

        assertions = [
          {
            assertion = cfg.contextSize > 8192;
            message = "local-qwen needs contextSize > 8192 to leave room for input and output.";
          }
          {
            assertion = lib.all (name: builtins.hasAttr name models) (builtins.attrNames cfg.modelContextSizes);
            message = "local-qwen modelContextSizes contains an unknown model ID.";
          }
        ]
        ++ lib.mapAttrsToList (id: model: {
          assertion = contextSizeFor id > 8192;
          message = "local-qwen model ${id} needs contextSize > 8192.";
        }) models;

        # Only the public socket starts at boot. The proxy starts the router on
        # the first connection, retaining Nemotron/Hermes defaults until then.
        systemd.sockets.local-qwen-proxy = {
          description = "On-demand local Qwen API socket";
          wantedBy = [ "sockets.target" ];
          listenStreams = [ "127.0.0.1:18082" ];
        };

        systemd.services.local-qwen-proxy = {
          description = "Socket-activated proxy for the local Qwen router";
          requires = [ "local-qwen-proxy.socket" ];
          bindsTo = [ "local-qwen.service" ];
          after = [ "local-qwen.service" ];
          serviceConfig = {
            ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:18083";
            DynamicUser = true;
          };
        };

        # Starting either backend stops the other, preventing GPU contention.
        systemd.services.local-qwen = {
          description = "On-demand Qwen vision/tool model router for OpenCode";
          # Ordering as well as conflicts: wait for old GPU workers to exit.
          after = [ "network.target" ] ++ cfg.competingServices;
          conflicts = cfg.competingServices;
          serviceConfig = {
            ExecStart = lib.escapeShellArgs [
              "${cfg.package}/bin/llama-server"
              "--host"
              "127.0.0.1"
              "--port"
              "18083"
              "--models-preset"
              (toString presets)
              "--models-max"
              "1"
              "--models-autoload"
              "--timeout"
              "3600"
            ];
            # Do not let the proxy forward queued connections before the
            # router is listening. Listing models does not load their weights.
            ExecStartPost = lib.escapeShellArgs [
              "${pkgs.curl}/bin/curl"
              "--fail"
              "--silent"
              "--show-error"
              "--output"
              "/dev/null"
              "--retry"
              "60"
              "--retry-connrefused"
              "--retry-delay"
              "1"
              "--max-time"
              "1"
              "http://127.0.0.1:18083/v1/models"
            ];
            TimeoutStartSec = 90;
            DynamicUser = true;
            StateDirectory = "local-qwen";
            WorkingDirectory = "/var/lib/local-qwen";
            Environment = "HOME=/var/lib/local-qwen";
            Restart = "on-failure";
            RestartSec = 10;
            TimeoutStopSec = 60;
            # OOM is preferable to silently swapping tens of GB during a turn.
            MemorySwapMax = 0;
          };
        };

        home-manager.users.${cfg.user} = {
          programs.zsh.shellAliases.model-unload = toString (
            pkgs.writeShellScript "model-unload" ''
              set -euo pipefail
              models=$(${pkgs.curl}/bin/curl --fail --silent --show-error \
                http://127.0.0.1:18082/models | \
                ${pkgs.jq}/bin/jq -r '.data[] | select(.status.value == "loaded") | .id')
              while IFS= read -r model; do
                [ -n "$model" ] || continue
                ${pkgs.jq}/bin/jq -n --arg model "$model" '{model: $model}' | \
                  ${pkgs.curl}/bin/curl --fail --silent --show-error \
                    --header 'Content-Type: application/json' --data-binary @- \
                    http://127.0.0.1:18082/models/unload
                printf '\nUnloaded %s\n' "$model"
              done <<< "$models"
            ''
          );

          opencode.settings.providers.local-qwen = {
            name = cfg.providerName;
            package = "@opencode/ai/providers/openai-compatible";
            settings = {
              baseURL = "http://127.0.0.1:18082/v1";
              headerTimeout = 3600000;
              chunkTimeout = 3600000;
            };
            models = lib.mapAttrs (
              name: model:
              {
                inherit (model) name;
                capabilities = {
                  tools = true;
                  input = [
                    "text"
                    "image"
                  ];
                  output = [ "text" ];
                };
                compatibility.reasoningField = "reasoning_content";
                limit = {
                  context = contextSizeFor name;
                  output = 8192;
                };
                cost = {
                  input = 0;
                  output = 0;
                };
              }
              // lib.optionalAttrs (model ? requestBody) { body = model.requestBody; }
            ) models;
          };
        };
      };
    };
}
