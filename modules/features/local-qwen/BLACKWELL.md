# Local abliterated models on CapCUDell

The normal and bootstrap CapCUDell hosts select `localQwenBlackwell`. This
reuses the socket-activated Qwen router, not rogdesktop's Pascal placement
settings. OpenCode's default model is unchanged. Hermes uses the same Qwen
endpoint, defaulting to Qwen3.8 27B, with all four models registered in its
`Local Qwen` custom provider. Context limits are tuned per model and shared
with both clients rather than relying on the shared module's default.

## Hardware and selection

Observed on 2026-10-16: RTX PRO 2000 Blackwell, 16,311 MiB VRAM (306 MiB used at
inspection), SM 12.0; Core Ultra 7 265K, 20 hybrid cores; 62 GiB usable RAM,
32 GiB available, no swap. About 613 GiB disk was available. RAM/VRAM usage
will change with desktop applications.

| OpenCode model under `local-qwen/` | Quant / weight size | Intended placement |
| --- | --- | --- |
| `qwen3.8-27b-abliterated` | UD-DW IQ3_S / 11.49 GiB | Prefer all dense layers on GPU; fit automatically if memory is insufficient |
| `qwen3.6-35b-a3b-abliterated` | Q4_K / 20.22 GiB | Experts in first 20/40 blocks on CPU; later experts and other tensors GPU-preferred; context must be memory-tested |
| `qwen3.5-9b-abliterated` | Q6_K / 6.85 GiB | Prefer all layers on GPU; interactive fallback with higher precision |
| `qwen3.8-27b-coder390-abliterated` | IQ3_S3 / 11.31 GiB | Dense GPU-fit experimental coding challenger, not a demonstrated quality winner |

All models are abliterated derivatives with tool-capable base families. Neither
abliteration nor base-model benchmarks prove reliable agentic behavior after
quantization. The dense 27B Q4 used on rogdesktop is 15.42 GiB before cache and
scratch; copying it would force CPU spill and risk the throughput target.
The smaller IQ3 weights make GPU residency plausible, at a quality tradeoff.
The MoE retains Q4 precision and uses RAM for some expert computation, not
unified-memory oversubscription. Exact offloaded counts require runtime logs.
The locked runtime skips automatic fitting when CPU-expert tensor overrides
are already set. Its 262,144-token MoE trial failed to allocate the 5,120 MiB
KV cache; `fit-target` alone is not a memory guard for that model.

The host profile uses the existing locked llama.cpp package with CUDA 13,
the host's configured SM 12.0 target, flash attention on, F16 caches, eight CPU
threads and one slot. Context is overridden per model in
`local-qwen-blackwell.nix`, including each model's `fit-ctx` floor and client
limits. Dense-model fitting reserves 1,536 MiB relative to available VRAM and
cannot silently shrink the context. Vision encoders run
on CPU with at most 1,024 image tokens. MTP/speculative decoding is not enabled.
One model is resident at a time; service swapping is disabled.

Initial download is approximately **57.2 GB**, including four projectors, plus
runtime dependencies. Artifacts have pinned revisions and SHA-256 hashes;
Ollama downloads are not reused or deleted. No flake input update is needed.
CUDA 12 and all placement defaults remain unchanged for rogdesktop.

## Evaluate and activate

Please evaluate both affected configurations before activating. The `path:`
flake includes new files without staging them:

```sh
nix eval "path:$PWD#nixosConfigurations.capcuDell.config.system.build.toplevel.drvPath"
nix eval "path:$PWD#nixosConfigurations.capcuDellBootstrap.config.system.build.toplevel.drvPath"
# Regression check for the shared module, if desired:
nix eval "path:$PWD#nixosConfigurations.rogdesktop.config.system.build.toplevel.drvPath"
sudo nixos-rebuild switch --flake "path:$PWD#capcuDell"
```

Only a localhost API socket starts at boot. **The first API request stops
Ollama and its loader**, but not Hermes: both Hermes and OpenCode are clients
of the same router. Hermes requires the API socket rather than Ollama's loader.
Each model loads on its first inference request. OpenCode's `/models` lists the
four IDs above; Hermes's `/model` picker exposes them under `Local Qwen`.
Hermes WebUI uses its existing gateway connection to this configured agent.
Hermes is intentionally absent from the secrets-disabled bootstrap configuration.
The backend has one inference slot: simultaneous clients queue, and switching
models may require reloading weights. This does not promise parallel throughput.
The API is loopback-only but has no authentication against other local users.

```sh
local-qwen-check
local-qwen-bench --json "$HOME/.cache/capcudell-qwen-benchmark.json"
journalctl -u local-qwen -b --no-pager
nvidia-smi
free -h
```

The checker covers text, a function call and tool-result continuation, vision,
and single-model residency. It now discovers the configured models, including
Coder390. It is not a comprehensive autonomous-agent evaluation.

The benchmark excludes loading and a warm-up, then runs three uncached prompts
with 512 generated tokens per model. It reports **total generated tokens /
total generation seconds**, not an arithmetic average of rates. It separately
reports prefill and warm wall-clock throughput and exits nonzero if any model
does not strictly exceed **15 generation tok/s**. Raw `/completion` deliberately
ignores EOS for fixed-length timing; these are not chat-quality measurements.
Generation includes any generated reasoning, not only visible answer tokens.

For a near-capacity trial, pass `--prompt-tokens` to select an exact input
budget. This uses token IDs from the loaded model's tokenizer, excludes a
short warm-up, disables prompt caching, and rejects truncated or partially
cached inputs. Leave room for the generated tokens within the context limit.
For example, at a 32,768-token context:

```sh
local-qwen-bench --runs 2 --tokens 512 --prompt-tokens 32000
python3 -m unittest discover -s modules/features/local-qwen -p 'test_*.py'
```

These repeated-text throughput tests are not a long-context retrieval or
quality evaluation. Decode tok/s excludes prefill and model-loading time;
long-input end-to-end throughput can be substantially lower.

## Validated context limits (2026-10-16)

These are the largest tested passing contexts while retaining the intended
VRAM reserve. Each was validated with two uncached near-capacity prompts and
512 generated tokens per prompt. All four originally shared 16,384 tokens.

| Model | Final context | Input tokens per validation | Decode tok/s, both runs |
| --- | ---: | ---: | ---: |
| Qwen3.8 27B IQ3_S | **45,056** | 44,288 | **15.78 / 15.83** |
| Qwen3.8 27B Coder390 | **45,056** | 44,288 | **16.06 / 16.05** |
| Qwen3.5 9B Q6_K | **245,760** | 244,992 | **16.52 / 16.53** |
| Qwen3.6 35B-A3B MoE | **143,360** | 142,592 | **30.68 / 31.01** |

The next tested increments failed: 47,104 for both 27B models, 253,952 for
9B, and 147,456 for MoE's memory reserve. The MoE limit is **memory-limited,
not decode-speed-limited**, with the existing 20 CPU-expert layers. These
settings do not change quantization, expert placement, or cache precision.

### Context sweep

Every context change was activated with `nr` on CapCUDell before inference.
The sweep kept weights, quantization, F16 caches, CPU threads, expert
placement, and the 1,536 MiB fit target unchanged. Each initial long trial
used context minus 768 input tokens and 256 generated tokens (512 in the
9B trials above 128K); final validation uses two independent 512-token generations.
Rates below are the server's decode timing, excluding prefill and loading.

| Context tokens | 27B IQ3_S | 27B Coder390 | 9B Q6_K | 35B-A3B MoE |
| ---: | ---: | ---: | ---: | ---: |
| 32,768 | 16.26 | 16.48 | 32.21 | 44.62 |
| 40,960 | 16.06 | 16.33 | — | — |
| 45,056 | 15.85 | 16.08 | — | — |
| 47,104 | **14.14** | **14.35** | — | — |
| 49,152 | **12.88** | **13.03** | — | — |
| 65,536 | — | — | 27.69 | 40.28 |
| 131,072 | — | — | 23.29 | 28.80 |
| 143,360 | — | — | — | 30.68–31.01 (validation) |
| 229,376 | — | — | 17.31 | — |
| 245,760 | — | — | 16.52–16.53 (validation) | — |
| 253,952 | — | — | **14.06–14.12** | — |
| 262,144 | — | — | **13.33** | **KV-cache allocation failed** |

The 196,608-token MoE profile loaded and decoded short prompts quickly, but
left only 550 MiB free VRAM; it was rejected without a long-prompt test to
preserve the intended memory headroom. Automatic fitting cannot enforce
that reserve with this model's CPU-expert tensor overrides.

The 45,056-token dense profiles passed two 512-token generations each at
44,288 input tokens: **15.78 / 15.83 tok/s** for 27B and **16.06 / 16.05
tok/s** for Coder390. The next tested increment, 47,104, failed for both.

The MoE passed both 512-token validation runs with 142,592-token inputs at
143,360 context: **30.68 / 31.01 tok/s**. Free VRAM was **1,596 MiB**, both
before and after the long runs, retaining the intended 1,536 MiB reserve.
The next 4,096-token increment, 147,456, left **1,516 MiB** free and was
rejected before long-prompt validation.

Raw timings, VRAM snapshots, and subsequent rebuild logs are retained in
`~/.cache/qwen-context-tuning-20261016/`. More precise context boundaries or
different prompts, desktop GPU load, vision, and concurrent clients can
change the results; these are tested operating points, not universal maxima.

## Tune against actual measurements

Inspect model weight/cache/scratch allocations and free RAM. A nominal
"all layers offloaded" message does not imply CPU-overridden experts are on GPU.
Test long prompts, images, and real tool sessions before declaring a winner.
Use the same prompt size and output length when comparing profiles:

```sh
local-qwen-bench --model qwen3.6-35b-a3b-abliterated --runs 5 --tokens 512
# Increase prompt length, while staying below context minus output budget:
local-qwen-bench --prompt-repeats 512 --json "$HOME/.cache/capcudell-qwen-long.json"
```

Tune in `modules/features/local-qwen-blackwell.nix`, rebuilding between trials:

- Sweep `cpuExpertLayers` through 24, 20, 16, and 12. Lower values put more
  experts on GPU. Inspect available VRAM explicitly: this runtime cannot fit
  automatically with expert overrides. Prefer the measured throughput/latency
  winner, not the lowest CPU count.
- Sweep `threads` through 6, 8, 12, and 20. More hybrid cores can be slower
  for bandwidth-bound expert computation.
- If dense layers spill, close GPU applications or test a smaller context
  (currently the shared module requires more than 8,192 tokens). Do not remove
  safety headroom merely to report more GPU layers.
- Keep the highest-quality model that passes both >15 tok/s and realistic
  multi-step tool tasks. Do not average a slow model together with a fast one
  to hide a failing profile. The 9B fallback is the lowest-risk speed choice.

`model-unload` releases the resident model without stopping either client.
Ollama is no longer installed. To stop inference completely, stop Hermes first
and disable socket activation until you want to resume:

```sh
sudo systemctl stop hermes-agent hermes-webui
sudo systemctl stop local-qwen-proxy.socket local-qwen-proxy.service local-qwen.service
# Later, restart Qwen's socket and its clients:
sudo systemctl start local-qwen-proxy.socket
sudo systemctl start hermes-agent hermes-webui
```
