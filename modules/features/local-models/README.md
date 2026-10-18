# Local Models options for OpenCode (rogdesktop)

For CapCUDell's separate Blackwell profiles, see [BLACKWELL.md](BLACKWELL.md).
For the ongoing real-agent benchmark and placement experiments, see
[AGENTIC.md](AGENTIC.md). Its profiles supersede the older throughput-only
recommendations below; they are not yet final optimized settings.

`../local-models.nix` adds three models under the `local-models` provider, without
changing OpenCode's default model or the existing Nemotron/Hermes configuration.
Both normal and bootstrap host configurations import this feature.

### Experimental K2 Horizon addition (rogdesktop only)

`localModelsPascal` additionally selects
`local-models/k2-horizon-mova-36b-a4b-abliterated`, without changing the default model.
It uses [mradermacher's imatrix Q4_K_M GGUF](https://huggingface.co/mradermacher/K2-Horizon-MoVA-36B-A4B-uncensored-i1-GGUF)
of InfinimindCreations' rank-3 abliterated checkpoint. Among matching MoVA 36B
abliterated GGUF repositories found on 2026-10-18, it had the most monthly downloads
(10,696; the Heretic imatrix alternative had 9,258). Popularity is not a quality
evaluation; the original K2 Intelligence Index score does not validate this variant.

- Immutable revision and LFS SHA-256 pin a **22.37 GB / 20.83 GiB** weight file.
- **Text-only**, with tool support advertised; no vision projector is fetched.
- Initial **16,384-token context**, 8,192-token output cap, all routed experts
  on CPU, automatic layer fitting, six threads. Placement/context remain unvalidated.
- Requests select high reasoning effort, temperature 1.0, top-p 0.95. High effort
  follows the original model's guidance; the derivative's refusal tests used low.
- The Pascal profile uses the locked **llama.cpp b11454** source, the first upstream
  K2 Horizon implementation with reasoning/tool parsing. CUDA 12 and AVX2 dynamic
  dispatch are retained; other host profiles keep their existing runtime.

This requires a runtime rebuild and the additional weight download on activation.
Evaluate/build before switching, then validate text, tool round-trips, actual
allocation, and agent tasks. It has not been loaded or benchmarked here. Existing
Qwen models remain available. Download/runtime totals below describe the original
three-model setup, not this addition.

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

Rogdesktop selects `../local-models-pascal.nix`. Current agentic experiments retain
**16,384 / 65,536 / 32,768 context tokens** for 9B / MoE / 27B, respectively,
but change fitting headroom, expert/FFN placement, and request settings as described
in [AGENTIC.md](AGENTIC.md). Older near-full validation below applies to the exact
historical profiles tested, not automatically to these changed placements.
The MoE's Q8-cache/flash-attention settings override the conservative shared
defaults described above. Shared defaults remain available to other profiles;
discovery does not activate this host profile.

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

### Renaming from local-qwen

The feature modules are now `localModels`, `localModelsPascal`, and
`localModelsBlackwell`; options live under `services.local-models`. The provider
ID, systemd units, and helper commands also use `local-models` instead of
`local-qwen`. Model IDs and API ports are unchanged.

After rebuilding, reselect saved OpenCode/Hermes model choices that reference the
old provider (`local-qwen/<model>` or `custom:local-qwen`). Existing conversation
history is not rewritten. Before switching an existing installation, stop the old
units to release the API ports and GPU:

```sh
sudo systemctl stop local-qwen-proxy.socket local-qwen-proxy.service local-qwen.service
```

The new service creates `/var/lib/local-models` automatically. The old
`/var/lib/local-qwen` state (including any private systemd state directory) is
left untouched, not moved or deleted; model weights remain in the Nix store and
do not need to be copied. Historical benchmark artifact paths below are unchanged.

### Build

Add the new files to Git first so the Git-backed flake can see them:

```sh
git add -A -- 'modules/features/local-models*' 'modules/features/local-qwen*'
nix eval .#nixosConfigurations.rogdesktop.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.rogdesktopBootstrap.config.system.build.toplevel.drvPath
sudo nixos-rebuild switch --flake .#rogdesktop
# The first API request starts the router automatically:
curl --fail http://127.0.0.1:18082/v1/models
```

Only the lightweight API socket is started at boot, **not the router or models**.
The first connection to port 18082 starts a proxy and the router; the proxy waits
for the router's model-list endpoint on internal port 18083 before forwarding.
Hermes and OpenCode share this router; Hermes defaults to the interactive
abliterated Qwen3.5 9B model, with the context limit from the host profile.
Ollama is no longer installed. The optional Nemotron `llama-cpp` service conflicts
with this router to prevent competing backends from consuming the same GPU.
To stop inference and its clients:

```sh
sudo systemctl stop hermes-agent hermes-webui local-models
```

To prevent subsequent API requests from starting the router again, also stop the socket:

```sh
sudo systemctl stop local-models-proxy.socket local-models-proxy.service local-models.service
# Re-enable on-demand access when wanted:
sudo systemctl start local-models-proxy.socket
```

In OpenCode, open `/models` and choose:

- `local-models/qwen3.8-27b-abliterated`
- `local-models/qwen3.6-35b-a3b-abliterated`
- `local-models/qwen3.5-9b-abliterated`

Use a fresh session if the existing conversation exceeds the selected model's
context. Models load on the first request, so the first turn and switches take longer. The local
provider allows up to an hour for response headers and streamed chunk gaps.
Run `model-unload` in Zsh to release loaded models from RAM/VRAM without
stopping the router. The next model request loads it again.
The API binds only to loopback and has no authentication; local processes can
access it. OpenCode executes tools, not the model server's built-in agent tools.

## Validate on the machine

After activating, run the included text, tool-call/follow-up, and image tests:

```sh
local-models-check
journalctl -u local-models -b --no-pager
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
services.local-models = {
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

## Fresh rogdesktop measurements and prefill timing (2026-10-17, midday)

These results supersede the older operating-point recommendations below.
Weights, runtime, six threads, microbatch size, cache precision, flash attention,
and the 1,536 MiB reserve were held fixed at this sweep's starting settings.
Native context metadata reports 262,144 tokens. Each request used an uncached
exact-token prompt and one resident model; load/warm-up was excluded.

| Model / trial | Context | Input / output | Raw decode token/s | Prefill seconds | Mean decode GPU utilization | Minimum free VRAM |
| --- | ---: | --- | --- | --- | --- | ---: |
| **9B, selected under live desktop load** | **16,384** | 15,616 / 512, twice | **18.7472 / 18.8776** | **43.194 / 43.519** | **98.435% / 98.652%** | **1,549 MiB** |
| 9B, earlier lighter desktop load | 24,576 | 23,808 / 512, twice | 15.5099 / 15.4305 | 76.099 / 76.640 | 98.857% / 98.966% | 1,816 MiB |
| 9B, rejected final-load revalidation | 24,576 | 23,808 / 512, twice | 14.0034 / 13.2774 | 85.632 / 89.366 | 87.697% / 89.440% | 1,348 MiB |
| 9B, rejected next step | 26,624 | 25,856 / 512, twice | 14.9253 / 14.9326 | 85.160 / 85.528 | 98.933% / 98.967% | 1,736 MiB |
| MoE, original seven-GPU-expert split | 65,536 | 64,768 / 256 | 14.7254 | 1,097.162 (18m 17s) | 61.538% | 1,738 MiB |
| MoE, smaller-context alternative | 49,152 | 48,384 / 256 | 15.5057 | 870.569 (14m 31s) | 59.615% | 1,914 MiB |
| 27B, short-prompt screen only | 32,768 | 1,058 / 256 | 1.7586 | 31.556 | 9.758% | 1,948 MiB |

The selected 16,384-token 9B passes all three goals in both independent near-full
validation runs. Its decode utilization minimum was 98% in each run, with zero
time below 90%. The larger 26,624-token candidate failed speed in both runs
despite high GPU utilization. Although 24,576 initially passed under lighter
desktop load, final-load revalidation failed speed, utilization, and memory
reserve. Those later utilization minima were 80%/84%, with 60.61%/32.37% of
measured decode time below 90%. No other inference workload was introduced or
desktop application stopped. GPU graphics workloads make comparisons between
load conditions non-equivalent; the final profile is a **conservative tested
operating point, not a tightly bracketed maximum**. Automatic placement, f16
cache, and flash-attention-off settings were unchanged. The final 16K run's
lowest headroom was only 13 MiB above the reserve, so subsequent desktop
allocations can still invalidate it; automatic fitting is not a reservation.

The MoE used `n-cpu-moe=33` (seven expert layers on GPU), Q8 K/V cache, and flash
attention on. At 49,152 context, moving one more expert layer to GPU
(`n-cpu-moe=32`) left only **1,482 MiB free** after warm-up. It was rejected and
unloaded before a long request; automatic fitting is not a reliable guard with
explicit expert overrides. The 64K/49K decode utilization minima were 60%/56%,
respectively, with all measured decode time below 90%. Neither is qualifying;
49K has only one 256-output exploratory sample, not two final validations.
The starting 64K context was retained rather than silently weakening a goal.
During final activation checks, increased desktop GPU usage left that original
seven-GPU-expert split only **1,373 MiB free**, so it was immediately unloaded.
The final safety fallback moves one expert layer back to CPU (`n-cpu-moe=34`,
six expert layers on GPU), retaining 64K context, Q8 K/V, and flash attention.
Its final smoke test left **1,765 MiB free**. It is **not long-context validated**
at this placement, and no qualifying speed/utilization or final-placement
prefill time is claimed. The table's 18m 17s measurement is for the original
split, not a promise for this safer fallback.

The 27B failed its short-prompt speed screen; no fresh near-full prefill time or
qualifying long-context result is claimed. Its utilization minimum was 2%,
with all measured decode time below 90%. Earlier placement sweeps below also
found no qualifying CPU/GPU split. Its starting configuration was preserved.

Streaming token events delimit decode, and one-second GPU telemetry excludes
prefill/idle boundary samples. Raw per-run GPU statistics include time-weighted
means, minima, and fractions below 90%. Only the intended worker appeared in
compute-process snapshots; ordinary desktop applications stayed open.
Service swap remained zero. Prefill is separate from generation: the final 9B's
~18.7 token/s decode does **not** include its ~43-second fresh-prompt processing.
Synthetic throughput does not validate recall, tool use, or concurrency.

Raw timing JSON, stream boundaries, GPU telemetry, hardware details, starting
configuration, rebuild logs/exit codes, and final summary are saved under
`~/.cache/qwen-context-tuning-20261017-114244/`. Intermediate activations hit
conflicting inference-service startup races; the intended router was recovered
and each rebuild retried successfully before benchmarking. No unrelated
services were permanently disabled. `local-models-bench` now prints per-run
prefill seconds and wall time as well as decode throughput.

## Required 32K context follow-up (2026-10-17)

The user subsequently required at least **32,768 context tokens** for MoE and
27B while retaining 15 decode token/s; the 90% utilization goal and 1,536 MiB
reserve were not waived. A smaller-context follow-up was interrupted and is
not a completed measurement. The previously validated 9B profile was unchanged.

At context 32,768, the MoE with seven expert layers on GPU (`n-cpu-moe=33`)
processed 32,000 input tokens and generated 256 at **10.91 token/s**, **66.84%**
mean decode GPU utilization, and at least **1,644 MiB free VRAM**. This failed
both performance targets; 16K speed results do not qualify at the required 32K.

For 27B, an alternative split kept all 64 dense FFN layers on CPU
(`n-cpu-ffn=64`) and offloaded 44 attention/recurrent layers (`gpu-layers=44`,
automatic fitting disabled). Its short-prompt screen reached only **1.71 token/s**
and **8.52%** GPU utilization, with **1,936 MiB free VRAM**. The CPU-FFN split
did not outperform the previously screened whole-layer splits, and no near-full
validation was claimed. The runtime's CPU-FFN control is exposed through
`modelOverrides.<id>.cpuFfnLayers` for explicit placement experiments.

Neither model has a layer-only configuration validated at 32K and 15 token/s.
The failing splits were removed; both use safe baseline placement at the
requested 32K minimum (MoE all routed experts on CPU, 27B automatic whole-layer
fitting). These are explicitly **nonqualifying profiles**, not a claim that the
performance request was achieved. Changes to flash attention, cache precision,
weight quantization, runtime, or hardware are separate experiments requiring
agreement; splitting alone has not removed the CPU bottleneck.

Results and restoration logs: `~/.cache/qwen-context-tuning-20261017-012332/`.
The interrupted smaller-context run is preserved separately under
`~/.cache/qwen-context-tuning-20261017-011851/`.

## Initial near-full context and GPU placement tuning (2026-10-17)

Hardware/runtime: GTX 1070 (8,192 MiB), NVIDIA 580.173.02, Ryzen 5 2600X,
39 GiB RAM, CUDA 12 llama.cpp 0.6.0 build 11429 (`d812350`). The pinned GGUFs,
six threads, f16 KV cache, flash attention off, one slot, and output limit were
unchanged. The service used no swap. Each trial used one resident model and
excluded model loading and warm-up. Native GGUF context limits were 262,144.

Acceptance required at least 15 raw decode token/s, 90% mean GPU compute
utilization during each validation run's decode phase, and 1,536 MiB free VRAM.
GPU samples were taken once per second and aligned to streaming token events;
prefill/idle boundary samples were discarded. Compute-process snapshots showed
only the selected llama.cpp worker; normal desktop applications remained open.
GPU utilization here is device busy time, not VRAM occupancy or memory bandwidth.

| Model | Final context | Input / output per validation | Raw validation decode token/s | Mean decode GPU utilization | Minimum free VRAM |
| --- | ---: | --- | --- | --- | ---: |
| Qwen3.5 9B | 26,624 | 25,856 / 512, four independent runs | 15.1959 / 15.1918 / 15.1846 / 15.1851 | 98.83% / 98.80% / 98.73% / 98.77% | 1,652 MiB |
| Qwen3.6 35B-A3B | 24,576 (starting profile restored) | No qualifying validation | — | — | — |
| Qwen3.8 27B | 32,768 (starting profile restored) | No qualifying validation | — | — | — |

The 9B used automatic whole-layer fitting, not a changed cache precision or
expert split. Its validation samples had no GPU utilization readings below 90%
(minimum readings 98%). Prefill of 25,856 tokens took about 84 seconds; decode
speed excludes that time. The next larger tested context, 28,672 (27,904 input,
256 output), failed at 14.69 decode token/s despite 98.79% GPU utilization and
1,572 MiB free VRAM. Four full validation runs were used because the passing
point has a narrow speed margin. This is the largest tested passing point at
2,048-token search resolution, not a universal maximum or concurrency guarantee.

Placement trials did not find a qualifying profile for the other models:

- **MoE:** moving four/six expert layers to GPU left short-prompt utilization
  around 40%. At context 24,576, seven GPU expert layers (`n-cpu-moe=33`)
  achieved 12.98 token/s and 66.81% GPU utilization on 23,808 input + 256 output,
  retaining 1,822 MiB free. Eight GPU expert layers at that context left only
  1,434 MiB free and were rejected before the long request. At context 16,384,
  seven GPU expert layers achieved 15.66 token/s / 61.17% utilization; eight
  (`n-cpu-moe=32`) achieved 15.74 token/s / 62.58% on 15,616 input + 256 output,
  leaving just 1,568 MiB free. Another expert layer would exceed the reserve.
  Smaller context met the speed floor but not the GPU-utilization target.
- **27B:** context 32,768 with automatic placement managed 1.81 token/s and
  8.36% utilization on a short prompt. Explicit 17/19 GPU-layer trials reached
  only 1.83/1.97 token/s and 10.45%/11.72% utilization; the 19-layer trial touched
  the 1,536 MiB reserve. Twenty layers left 1,308 MiB free and were rejected
  before the measured request. CPU-heavy dense inference remained far below
  target; no near-full validation was claimed.

The failed trials were not persisted: MoE retains all routed experts on CPU and
27B retains automatic fitting, both at their starting contexts. They remain
explicitly nonqualifying, not optimized profiles. More GPU offload did not remove
the CPU bottleneck, and safety headroom was not reduced to force utilization.

Raw reports, streaming timing boundaries, GPU telemetry, worker arguments,
VRAM/RAM/process snapshots, per-candidate profiles, rebuild logs/exit codes, and
`summary.json` are under `~/.cache/qwen-context-tuning-20261017-000340/`.
The initial baseline is under `~/.cache/qwen-context-tuning-20261016-231946/`.
An activation race with competing wanted backends was resolved by stopping the
on-demand Qwen router before each switch and starting it through the API after
activation; no competing service was permanently disabled. These synthetic
throughput tests do not establish recall, agent/tool quality, vision performance,
or end-to-end latency.

## Historical context tuning (2026-10-16)

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
