# Local Qwen options for OpenCode (rogdesktop)

For CapCUDell's separate Blackwell profiles, see [BLACKWELL.md](BLACKWELL.md).

`../local-qwen.nix` adds three models under the `local-qwen` provider, without
changing OpenCode's default model or the existing Nemotron/Hermes configuration.
Both normal and bootstrap host configurations import this feature.

## Memory placement

| Model | Weights | Placement |
| --- | --- | --- |
| Qwen3.8 27B Abliterated | UD-DW Q4_K_M, 16.55 GB | Automatically fit as many whole layers as possible on GPU; remaining layers execute on CPU from system RAM |
| Qwen3.6 35B-A3B Abliterated | Q4_K, 21.71 GB | Routed experts execute on CPU from RAM; automatically fit remaining tensors/layers on GPU |
| Qwen3.5 9B Abliterated | Q4_K_M, 5.63 GB | Prefer GPU layers, automatically spilling layers to CPU/RAM if the configured cache leaves insufficient VRAM |

The vision encoders (0.90–0.93 GB each) run on CPU, with images capped at 1,024
tokens. This protects VRAM from transient encoder allocations. Six CPU threads,
64-token microbatches, f16 caches, and no flash attention are conservative Pascal
defaults. CPU weights use llama.cpp's default memory mapping; RAM is where those
weights reside, not a third compute device. Swap is disabled for this service.

Automatic fitting reserves a **1,536 MiB margin relative to available GPU
memory**, and cannot reduce each model's explicitly configured context.
The exact split is computed at model load, not guessed from file sizes. OpenCode
advertises the same context and an 8,192-token output limit. Prompt snapshot RAM
caching and recurrent checkpoints are disabled to avoid additional RAM growth.
Only **one model** can be loaded at a time; selecting another evicts the previous
one. Long prefill and CPU vision encoding will still be slow on the Ryzen 2600X.
MTP/speculative decoding is not enabled, even for files containing MTP tensors.

The tuned context defaults are **30,720 tokens for 9B** and **24,576 for the MoE**.
The 27B retains the **32,768-token fallback**, but does **not** meet the 15 token/s
target. See the long-input measurements below; the original 32K short-prompt
benchmark did not establish sustained speed at long input lengths.

These are conservative profiles, **not exhaustively optimized placements**.
Check actual allocation and peak usage with text, images, tools, and long prompts
before increasing context or putting more experts on the GPU. The fit margin is
not a reservation against another application subsequently allocating VRAM.
Do not render with SheepIt/Blender or load another inference runtime concurrently.

All six downloads use immutable Hugging Face revisions and SHA-256 hashes from
the repositories' LFS metadata. The runtime comes from the locked `llm-agents`
nixpkgs input, with CUDA 12 and the host's SM 6.1 capability. No flake input update
is required. First build downloads about **46.6 GB**, excluding runtime/build
dependencies and the separate existing Nemotron model. No Ollama files are reused,
changed, or deleted.

## Evaluate and activate

Add the new files to Git first so the Git-backed flake can see them:

```sh
git add modules/features/local-qwen.nix modules/features/local-qwen
nix eval .#nixosConfigurations.rogdesktop.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.rogdesktopBootstrap.config.system.build.toplevel.drvPath
sudo nixos-rebuild switch --flake .#rogdesktop
# The first API request starts the router automatically:
curl --fail http://127.0.0.1:18082/v1/models
```

Only the lightweight API socket is started at boot, **not the router or models**.
The first connection to port 18082 starts a proxy and the router; the proxy waits
for the router's model-list endpoint on internal port 18083 before forwarding.
This stops Ollama, its model loader, Nemotron's `llama-cpp`, and Hermes services
via systemd conflicts. Starting those services again stops the router and proxy,
but leaves the socket ready to activate Qwen on the next connection. This prevents
competing backends from consuming the same 8 GiB GPU. It does not delete data or
change their settings. Restore the usual services when finished:

```sh
sudo systemctl stop local-qwen
sudo systemctl start ollama llama-cpp
# On the normal configuration when Hermes is wanted:
sudo systemctl start hermes-agent hermes-webui
```

To prevent subsequent API requests from starting Qwen again, also stop the socket:

```sh
sudo systemctl stop local-qwen-proxy.socket local-qwen-proxy.service local-qwen.service
# Re-enable on-demand access when wanted:
sudo systemctl start local-qwen-proxy.socket
```

In OpenCode, open `/models` and choose:

- `local-qwen/qwen3.8-27b-abliterated`
- `local-qwen/qwen3.6-35b-a3b-abliterated`
- `local-qwen/qwen3.5-9b-abliterated`

Use a fresh session if the existing conversation exceeds the selected model's
context. Models load on the first request, so the first turn and switches take longer. The local
provider allows up to an hour for response headers and streamed chunk gaps.
Run `model-unload` in Zsh to release loaded Qwen models from RAM/VRAM without
stopping the router. The next model request loads it again.
The API binds only to loopback and has no authentication; local processes can
access it. OpenCode executes tools, not the model server's built-in agent tools.

## Validate on the machine

After activating, run the included text, tool-call/follow-up, and image tests:

```sh
local-qwen-check
journalctl -u local-qwen -b --no-pager
nvidia-smi
free -h
```

Review each child's `load_tensors` and context/compute buffer sizes. Confirm CPU
expert overrides for the MoE, GPU offloaded layer counts for both dense models,
and desktop headroom under peak load. The checker switches through all three
models and verifies the router leaves only one resident. It does not benchmark
long-context performance or prove reliable autonomous task completion.

To tune after measurement, set these in the host configuration and rebuild:

```nix
services.local-qwen = {
  # Fallback for models without a per-model override:
  contextSize = 32768;
  # Runtime allocation, minimum fitting context, and OpenCode limits stay aligned:
  modelContextSizes = {
    "qwen3.5-9b-abliterated" = 30720;
    "qwen3.6-35b-a3b-abliterated" = 24576;
  };
  # null (default) keeps all routed experts on CPU. Try progressively smaller
  # block counts only after checking VRAM and latency, e.g. 36, then 32.
  cpuExpertLayers = null;
};
```

Automatic whole-layer fitting remains a fallback if partially GPU-resident
experts are requested. More GPU experts can displace other layers/cache; compare
end-to-end latency, not just offloaded layer counts. Abliteration/quantization
can degrade tool use and reasoning; the base models' benchmarks do not establish
these variants' quality.

Increasing allocated context alone does not demonstrate long-context speed.
For throughput acceptance, separately measure short-prompt decoding and decoding
after prefilling the usable input budget (configured context minus the 8,192-token
output budget). Report prefill time separately; a 15 generated-token/s result does
not imply fast processing of a fresh long prompt. Synthetic throughput tests also
do not establish long-context retrieval or tool-use quality.

## Context tuning (2026-10-16)

Using the same installed runtime, GGUFs, and conservative settings, the tuning
loop checked 32K first, searched downward when it failed, and refined the passing
boundary in 2,048-token steps. Each candidate got a 64-token warm-up and three
uncached 837-token prompts generating 128 tokens each. Candidates passing 15
token/s in all three short trials then processed an uncached synthetic token-array
prompt of `context - 8192` tokens and generated 512 tokens. Actual allocated
context and processed token counts were verified; fitting could not shrink them.

| Model | Persisted context | Long input tokens | Long-input generation tok/s | Prefill time | Next larger tested failure |
| --- | ---: | ---: | ---: | ---: | --- |
| Qwen3.5 9B | 30,720 | 22,528 | 16.47 | 68.5 s | 32,768: 14.68 tok/s |
| Qwen3.6 35B-A3B | 24,576 | 16,384 | 15.46 | 411.6 s | 26,624: 14.42 tok/s |
| Qwen3.8 27B | 32,768 (unchanged; no passing profile) | Not tested | Failed short-prompt screening | — | 16K/24K/32K all about 1.9 tok/s even on short prompts |

9B also passed at 24,576 (18.56 tok/s), 26,624 (17.83), and 28,672 (17.10).
The MoE failed at 32,768 (12.97 tok/s). These are the largest **tested** passing
contexts, not exact mathematical limits or a guarantee that every generated
token/workload remains above 15 tok/s. In particular, the MoE has little margin,
and the test did not generate the entire 8,192-token output allowance. More
generation, images, different prompts, or competing desktop load can be slower.
No cache quantization, flash-attention changes, or expert-placement changes were
used. The initial loop and refinement took about 59 minutes; the initial loop's
cgroup peaked at 34.7 GiB with no swap use.

Both selected profiles subsequently passed the router's text, tool-call and
follow-up, image-color, actual-context, and single-resident-model checks. The 27B
was not removed or falsely classified as meeting the speed floor.

Raw JSON results, per-context logs, and the benchmark script are preserved under
`~/.cache/opencode-local-qwen/context-tuning-2026-10-16/` (`initial/` and
`refinement/`). These measurements do not establish retrieval or agent quality.

## Initial 32K short-prompt measurements (2026-10-16)

Tested on the GTX 1070 / Ryzen 2600X machine with the installed CUDA 12
llama.cpp 0.6.0 runtime, one model resident and the full 32K context allocated.
After a 64-token warm-up, each model ran three uncached 837-token prompts with
256 generated tokens. The table reports median llama.cpp timings, excluding
model loading; these are short-text throughput measurements, not long-context
agent benchmarks. These are historical 32K results, before per-model context tuning.

| Model | Generation tok/s | Prefill tok/s | Peak total GPU memory | Actual placement |
| --- | ---: | ---: | ---: | --- |
| Qwen3.5 9B | 16.15 | 272.83 | 6,506 MiB | 29/33 runtime-counted layers on GPU (28 transformer layers + output); remaining 4 transformer layers on CPU |
| Qwen3.6 35B-A3B | 17.34 | 44.27 | 3,479 MiB | All non-expert layer tensors offloaded; routed experts remain CPU-mapped in RAM |
| Qwen3.8 27B | 1.47 | 29.68 | 6,303 MiB | 16/66 runtime-counted layers on GPU (15 transformer layers + output); remaining transformer layers on CPU; file includes an additional MTP block |

GPU weight buffers were 4,283 MiB (9B), 1,303 MiB (MoE), and 4,345 MiB (27B).
CPU-mapped model buffers were respectively 1,073, 19,777, and 11,094 MiB.
The MoE's `offloaded 42/42 layers` message does **not** mean all weights are in
VRAM: expert tensor overrides keep most of its weight bytes on CPU. Vision
encoders were CPU-only. Peak GPU memory includes desktop applications; it is
not just model weights. No service swapping or OOM events occurred.

All six files passed full SHA-256 verification. All models passed the included
text, tool-call/follow-up, image-color, and single-resident-model checks. For
interactive use, 9B offers much faster prefill; the MoE has slightly faster
decoding. The dense 27B works but its CPU-heavy placement makes it very slow.

Raw results and allocation logs from this run are in
`~/.cache/opencode-local-qwen/benchmark.json` and the adjacent per-model `.log`
files. Detailed allocation logging was enabled temporarily for measurement and
removed afterward; no placement settings were changed by these tests.
