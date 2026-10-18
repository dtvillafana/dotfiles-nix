# Nemotron on rogdesktop

Optional feature, no longer selected by rogdesktop. Hermes now uses the
abliterated Qwen3.5 9B through the local Qwen llama.cpp router; Ollama has been
removed. The instructions below describe the historical Nemotron setup and
require explicitly selecting `self.nixosModules.nemotron` first.

## Model and runtime

- Darkstar Nemotron 3.5 Lightning 30B-A3B Abliterated, mradermacher Q4_K_M.
  [Source model card](https://huggingface.co/HangGlidersRule/Darkstar-Nemotron-3.5-Lightning-30B-A3B-Abliterated-BF16)
  and [GGUF card](https://huggingface.co/mradermacher/Darkstar-Nemotron-3.5-Lightning-30B-A3B-Abliterated-BF16-GGUF).
- The GGUF revision and SHA-256 are pinned in `../nemotron.nix`. The first build
  downloads about 25.4 GB into the Nix store, independently of Ollama's cache.
- The publisher reports zero refusals on a 200-prompt suite, not a guarantee of
  zero refusals or unchanged capability. Tool-call and reasoning quality after
  abliteration/quantization still need local validation.
- llama.cpp comes from the existing locked `llm-agents` nixpkgs input (currently
  v0.6.0). CUDA 12 is explicitly selected, using rogdesktop's CUDA capability
  6.1; CPU backends include runtime AVX2 dispatch for the Ryzen 2600X.
- The GGUF contains its own Jinja chat/tool template. `--jinja` enables it; no
  Ollama-specific renderer or hand-written replacement template is used.

The initial split puts routed experts in RAM and the remaining tensors on the
GPU. Six CPU threads, f16 caches, no flash attention, and a 128-token microbatch
are conservative starting settings for the GTX 1070. Automatic fitting is off:
an allocation failure must not silently reduce the 64K context. This is an
**unbenchmarked starting profile**, not a proven optimal split.

## Evaluate and activate

After adding new files to Git so the flake can see them:

```sh
nix eval .#nixosConfigurations.rogdesktop.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.rogdesktopBootstrap.config.system.build.toplevel.drvPath
sudo nixos-rebuild switch --flake .#rogdesktop
curl --fail http://127.0.0.1:18080/health
journalctl -u llama-cpp -b
```

Hermes is configured separately to use Qwen, not this service. Bootstrap omits
secret-dependent Hermes services. This service keeps the model resident; while
it is running, SheepIt's GPU contention monitor will inhibit rendering.

## Tune without rebuilding

Stop the production server, Qwen router, and agents first, and stop SheepIt if
it is rendering.

```sh
sudo systemctl stop hermes-webui hermes-agent local-qwen-proxy.socket local-qwen llama-cpp
nemotron-test-server
```

The helper runs in the foreground on localhost:18081 with the same 64K profile.
Ctrl-C stops it. Run candidates one at a time:

```sh
# Whole-layer offloading baseline (no CPU expert overrides).
NEMOTRON_CPU_EXPERT_LAYERS=auto nemotron-test-server

# Experts in early blocks stay on CPU; later expert blocks move to GPU.
# Try 52, 48, 44, 40, ...; lower counts consume more VRAM.
NEMOTRON_CPU_EXPERT_LAYERS=48 nemotron-test-server
NEMOTRON_CPU_EXPERT_LAYERS=44 NEMOTRON_THREADS=12 nemotron-test-server
```

`NEMOTRON_GPU_LAYERS` can also cap GPU layers if non-expert allocations do not
fit. Additional llama-server arguments can be passed to the helper, for example
`--ubatch-size 64`. No service settings are changed by these tests.
With GPU layers set to `auto`, fitting is enabled with a 65,536-token minimum
context and a 1 GiB VRAM margin; fixed placements keep fitting disabled.

In a second terminal, wait for `/health`, then use the same prompt for each
candidate. `/completion` exposes native llama.cpp timing fields:

```sh
curl --fail http://127.0.0.1:18081/health
curl --fail http://127.0.0.1:18081/completion \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Explain how a CPU cache works.","n_predict":128,"seed":42,"temperature":0,"cache_prompt":false}'
nvidia-smi
```

Warm up first, then repeat. Compare `timings.prompt_per_second` and
`timings.predicted_per_second`, startup CPU/GPU buffer sizes, and peak RAM/VRAM.
Also test representative long prompts, streamed `/v1/chat/completions`, tool
calls with tool-result follow-ups, and time to first token in Hermes. Allocating
64K while testing a short prompt does **not** measure long-context performance.
Reject swapping, out-of-memory failures, desktop instability, or malformed tool
calls. Leave roughly 0.75–1 GiB VRAM for the desktop; `--fit off` does not reserve
this automatically.

Persist the winner in `modules/hosts/rogdesktop/configuration.nix`, for example:

```nix
services.nemotron = {
  cpuExpertLayers = 48; # Illustrative only: use measured results.
  threads = 6;
};
```

`cpuExpertLayers = null` restores all experts on CPU. N counts **model blocks**,
including non-expert blocks, not the number of MoE blocks. The GGUF has 53 blocks
including its MTP block; speculative decoding is not enabled by this profile.

Restore production after testing:

```sh
sudo systemctl start llama-cpp hermes-agent hermes-webui
```
