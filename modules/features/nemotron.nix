{ inputs, ... }:
{
  flake.nixosModules.nemotron =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.nemotron;
      llmPkgs = import inputs.llm-agents.inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config = pkgs.config;
      };
      # The locked llm-agents nixpkgs has Nemotron 3.5 support and AVX2 CPU
      # dispatch. CUDA 12 still supports Pascal; CUDA 13 no longer does.
      llama = llmPkgs.llama-cpp.override {
        cudaSupport = true;
        cudaPackages = llmPkgs.cudaPackages_12;
      };
      model = pkgs.fetchurl {
        name = "darkstar-nemotron-3.5-lightning-30b-q4_k_m.gguf";
        url = "https://huggingface.co/mradermacher/Darkstar-Nemotron-3.5-Lightning-30B-A3B-Abliterated-BF16-GGUF/resolve/b4332d386fef8fc8c6c5fdc24b11efa56b8e9a79/Darkstar-Nemotron-3.5-Lightning-30B-A3B-Abliterated-BF16.Q4_K_M.gguf";
        hash = "sha256-ICrwfXe1Hxp1zrN+CN9AdFu4XU5s4RLqfOFcv9N9DZo=";
      };
      commonFlags = [
        "--alias"
        "darkstar-nemotron-3.5-lightning:30b"
        "--ctx-size"
        "65536"
        "--parallel"
        "1"
        # Conservative Pascal defaults; do not depend on flash attention or
        # quantized-cache support for this hybrid recurrent architecture.
        "--flash-attn"
        "off"
        "--cache-type-k"
        "f16"
        "--cache-type-v"
        "f16"
        "--batch-size"
        "512"
        "--ubatch-size"
        "128"
        "--jinja"
        "--temp"
        "0.6"
        "--top-p"
        "0.95"
        "--top-k"
        "0"
        "--min-p"
        "0"
      ];
      # Automatic whole-layer placement may fit layers, but never shrink 64K.
      autoFitFlags = [
        "--fit"
        "on"
        "--fit-ctx"
        "65536"
        "--fit-target"
        "1024"
      ];
      placementFlags =
        if cfg.cpuExpertLayers == null then
          [ "--cpu-moe" ]
        else
          [
            "--n-cpu-moe"
            (toString cfg.cpuExpertLayers)
          ];
      testServer = pkgs.writeShellApplication {
        name = "nemotron-test-server";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if systemctl is-active --quiet llama-cpp.service; then
            echo 'Stop llama-cpp.service before testing: sudo systemctl stop hermes-agent hermes-webui llama-cpp' >&2
            exit 1
          fi
          placement=()
          cpu_layers="''${NEMOTRON_CPU_EXPERT_LAYERS:-${
            if cfg.cpuExpertLayers == null then "all" else toString cfg.cpuExpertLayers
          }}"
          gpu_layers="''${NEMOTRON_GPU_LAYERS:-${toString cfg.gpuLayers}}"
          case "$cpu_layers" in
            all) placement=(--cpu-moe) ;;
            auto) gpu_layers="''${NEMOTRON_GPU_LAYERS:-auto}" ;;
            *)
              if [[ ! "$cpu_layers" =~ ^[0-9]+$ ]]; then
                echo 'NEMOTRON_CPU_EXPERT_LAYERS must be all, auto, or a nonnegative block count' >&2
                exit 1
              fi
              placement=(--n-cpu-moe "$cpu_layers")
              ;;
          esac
          fit=(--fit off)
          if [[ "$gpu_layers" == auto ]]; then
            fit=(${lib.escapeShellArgs autoFitFlags})
          fi
          exec ${llama}/bin/llama-server \
            --model ${model} \
            ${lib.escapeShellArgs commonFlags} \
            --host 127.0.0.1 --port "''${NEMOTRON_PORT:-18081}" \
            --threads "''${NEMOTRON_THREADS:-${toString cfg.threads}}" \
            --threads-batch "''${NEMOTRON_THREADS:-${toString cfg.threads}}" \
            --gpu-layers "$gpu_layers" "''${fit[@]}" "''${placement[@]}" "$@"
        '';
      };
    in
    {
      options.services.nemotron = {
        cpuExpertLayers = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.unsigned;
          default = null;
          description = ''
            Keep experts in the first N model blocks in RAM. Null keeps all
            routed expert weights on the CPU, while other tensors use the GPU.
            N counts model blocks, not just blocks containing experts.
          '';
        };
        gpuLayers = lib.mkOption {
          type = lib.types.either (lib.types.enum [
            "all"
            "auto"
          ]) lib.types.ints.unsigned;
          default = "all";
          description = "Maximum GPU layers, subject to CPU expert placement overrides.";
        };
        threads = lib.mkOption {
          type = lib.types.ints.positive;
          default = 6;
          description = "CPU inference and prompt-processing threads.";
        };
      };

      config = {
        services.llama-cpp = {
          enable = true;
          package = llama;
          inherit model;
          host = "127.0.0.1";
          port = 18080;
          extraFlags =
            commonFlags
            ++ placementFlags
            ++ (
              if cfg.gpuLayers == "auto" then
                autoFitFlags
              else
                [
                  "--fit"
                  "off"
                ]
            )
            ++ [
              "--gpu-layers"
              (toString cfg.gpuLayers)
              "--threads"
              (toString cfg.threads)
              "--threads-batch"
              (toString cfg.threads)
            ];
        };

        # Do not release dependent agents until the model actually serves HTTP.
        systemd.services.llama-cpp = {
          serviceConfig = {
            TimeoutStartSec = "15min";
            RestartSec = lib.mkForce 10;
          };
          postStart = ''
            for attempt in $(seq 1 420); do
              if ${pkgs.curl}/bin/curl --fail --silent --max-time 2 \
                http://127.0.0.1:${toString config.services.llama-cpp.port}/health >/dev/null; then
                exit 0
              fi
              sleep 2
            done
            echo 'Nemotron did not become ready' >&2
            exit 1
          '';
        };

        environment.systemPackages = [
          llama
          testServer
        ];
      };
    };
}
