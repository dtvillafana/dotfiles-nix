# Local Models options for OpenCode (rogdesktop)

For CapCUDell's separate Blackwell profiles, see [BLACKWELL.md](BLACKWELL.md).
For the ongoing real-agent benchmark and placement experiments, see
[AGENTIC.md](AGENTIC.md). Its profiles supersede the older throughput-only
recommendations below; they are not yet final optimized settings.

`../local-models.nix` adds three models under the `local-models` provider, without
changing OpenCode's default model or the existing Nemotron/Hermes configuration.
Both normal and bootstrap host configurations import this feature.

### Accepted K2 MoVA 32K profile (2026-10-19, rogdesktop only)

This profile supersedes the historical 16K MoVA settings below. The user accepted
the measured performance despite falling slightly below the 9 tok/s target at
longer context. It is persisted in `../local-models-pascal.nix`:

- **32,768 context tokens**, shared by the backend and OpenCode client limits.
- Existing pinned abliterated **Q4_K_M weights**, six CPU/batch threads, flash
  attention on, **Q4 K/V cache**, and high reasoning effort.
- **49 GPU layers**, all routed FFN experts on CPU, and explicit CPU placement
  of `blk.3` through `blk.26` attention value-expert tensors. Other value experts
  and dense layers stay on GPU. Automatic fitting is disabled.
- GPU expert caching remains **disabled**: 256–1,024 MiB cache experiments
  slowed decode to about 3.7–3.9 tok/s on this machine.
- Runtime source is locked at `d6cf9acb25e6c657d6c6a4645ab7b69fce119995`, plus
  the pinned generic reasoning-closer parser fix. Both are reproducible without
  any benchmark-cache scripts or files.

| Actual prompt length | Measured decode |
| --- | ---: |
| 1,672 tokens | 9.48–9.62 tok/s |
| 4,770 tokens | 8.95–9.04 tok/s |
| 13,155 tokens | 8.57 tok/s |

The selected profile retained **2,136 MiB minimum free VRAM**. Uncached prefill
for 4,770 tokens took about **172s**. Text/tool/follow-up checks passed, but Q4 KV
agent-task quality and near-full 32K performance remain unvalidated. These are
replayed-request diagnostics, not verified agent completions. The benchmark's
**1,024 MiB guard is not a production-wide VRAM reservation**.

Artifacts: `~/.cache/local-k2-32k-tuning-20261019/`, including manifests, every
attempt, raw responses, telemetry, selected-profile repeat and longer-history
validation. Earlier placement experiments remain in
`~/.cache/local-k2-placement-tuning-20261019/`. The original control already
offloaded the output projection; the output-only override changed no allocation.
The accepted profile does not change the default model or Blackwell composition.
Persistence does not activate it: run `nr` to switch rogdesktop to these settings.

### Current K2 Horizon 7B replacement (rogdesktop only, 2026-10-19)

The existing `local-models/k2-horizon-7b-abliterated` ID now selects
[Candor Uncensored](https://huggingface.co/candor-lab/K2-Horizon-7B-Candor-Uncensored-GGUF),
an independent weight edit of IFM's original model, rather than Avicennasis Heretic.
The Q4_K_M file is pinned at revision
`684d33f62676e57731acf15f03a9cf9601b6a890`, SHA-256
`f46e3f6e15b3b04b778c645e89331a6c34c0b6130a45e70f04f483bcc986322f`
(5,592,227,200 bytes). Context, placement, sampling, high reasoning effort, and
the pinned full K2 tool template remain unchanged. The default model, MoVA, and
Blackwell profiles are unaffected.

The publisher reports 1,209/1,319 GSM8K correct versus 1,222/1,319 before editing,
and 0/300 harmless refusals, evaluated on this quantized file with high-effort
thinking. These are publisher claims, not local agent validation. Their evaluation
uses llama.cpp b11524, top-k 1,000, and an 8,192-token reasoning budget; this swap
does not adopt those settings or update the runtime. Tool use and agentic tasks
were not evaluated by the publisher. Local loading, template/parser compatibility,
and task quality remain unvalidated. Run `nr` to download and activate the replacement.

The Heretic results below are historical and do not describe Candor.

### Historical K2 Horizon 7B Heretic addition (rogdesktop only)

`localModelsPascal` additionally selects `local-models/k2-horizon-7b-abliterated`:
[mradermacher's Heretic imatrix GGUF](https://huggingface.co/mradermacher/K2-Horizon-7B-heretic-i1-GGUF),
quantized from [Avicennasis' abliterated checkpoint](https://huggingface.co/Avicennasis/K2-Horizon-7B-heretic).
It was the most-downloaded matching abliterated 7B GGUF repository found on
2026-10-18 (9,345 monthly downloads; the non-imatrix Heretic GGUF had 1,007).
Popularity does not establish quality or preserve the original model's AA score.

- Immutable revision and LFS SHA-256 pin **Q4_K_M**, **5.59 GB / 5.21 GiB**.
- Dense, text-only; uses the existing Pascal K2 runtime, without a projector.
- Initial **16,384-token context**, inherited **8,192-token output cap**, six
  threads, automatic layer fitting with **2,304 MiB** fitting headroom. This is
  not a guarantee of full GPU residency or a measured free-VRAM reserve.
- Requests select temperature 1.0, top-p 0.95, and high reasoning effort. The
  bundled minimal chat template does not serialize tool definitions or honor
  reasoning-effort selection; its tool smoke test failed. The profile now selects
  the full template from the same abliterated source checkpoint, pinned as the
  `k2-horizon-7b-chat-template` flake input. A private-worker text/tool/follow-up
  test passed with this template, including parsed reasoning and actual tool calls.
  The inherited output cap is below upstream's recommended 32,768 output tokens.
- Initial fitting loaded **23/37 GPU layers**, 3,228 MiB CUDA weights and
  1,408 MiB CUDA KV. The full-template smoke retained **2,453 MiB free VRAM**
  and decoded at **10.2–10.3 tok/s** on short requests. Sustained agent-context
  speed was lower in the baseline below; short requests are not agent scores.
- The template fix is activated. Both initial high-effort agent tasks timed out
  at **900s** without source edits or a final answer. The model made tool calls,
  then spent the final turn in repetitive, incoherent reasoning. Completed turns
  decoded at **6.75–7.92 tok/s**; measured prefill was at least **19.2s** for fix
  and **15.7s** for understanding. Interrupted-turn timings/usage are unknown.
  Minimum free VRAM was **2,327 / 1,634 MiB** respectively. This profile has no
  verified agent success yet; medium effort is a separate compatibility experiment.
  Existing models and the default model remain unchanged; Blackwell is unaffected.

New speed experiments and 7B artifacts are in
`~/.cache/local-k2-speed-tuning-20261019/`, separate from the earlier MoVA pass.
The high-effort baseline preserves the original fitting target and 16K context;
all subsequent tuning tracks remain separate rather than erasing its failures.

### Experimental K2 Horizon MoVA addition (rogdesktop only)

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
  on CPU, six threads. **28 GPU layers with f16 KV** passed both initial agent tasks;
  the **36-layer/Q8-KV/flash-attention profile** is provisionally selected after
  two matched repetitions. Broader testing exposed desktop-load memory stops;
  long-context validation remains pending. This is not an unconditional safe profile.
  Automatic fitting was rejected:
  CPU tensor overrides disable it, and the initial load failed allocating KV cache.
- Requests select temperature 1.0, top-p 0.95, and high reasoning effort, following
  the original model's guidance. Low effort failed the actual agent comparison:
  native tool-call markup was emitted inside `reasoning_content` and not executed.
  High effort was restored; short low-effort runtimes are not successes. The
  derivative's refusal tests used low, but do not validate agent/parser compatibility.
- The Pascal profile uses the locked **llama.cpp b11454** source, the first upstream
  K2 Horizon implementation with reasoning/tool parsing. CUDA 12 and AVX2 dynamic
  dispatch are retained; other host profiles keep their existing runtime.

The runtime rebuild and weight download completed on 2026-10-18. The explicit
split loaded **24/49 layers** on GPU, with 3,096 MiB CUDA weights, 1,472 MiB CUDA
KV, 1,600 MiB CPU KV, and 232 MiB CUDA compute buffers. A guarded text/tool/follow-up
smoke test retained **2,390 MiB free** and decoded at **6.3–7.7 tok/s** on short
requests. These are diagnostics, not agent-task scores. High reasoning effort
generated 257 tokens for a request to answer only `OK`, so end-to-end latency
must include reasoning. Artifacts: `~/.cache/local-k2-tuning-20261018/`.
The benchmark stop reserve is 1,024 MiB by explicit user approval; automatic
fitting headroom is a separate setting. Existing
Qwen models remain available. Download/runtime totals below describe the original
three-model setup, not this addition.

Initial agent comparison (same frozen fixtures, seed 42, 16K context, CPU experts,
high reasoning; one repetition/profile):

| GPU layers | Bug fix | Understanding | Measured prefill, fix / understanding | Minimum free MiB |
| --- | --- | --- | --- | ---: |
| 24 | Verified, 697.8s | Partial, 728.4s: invented frozen-dataclass claim | 177.2s / 152.9s | 2,067 |
| 28 | Verified, 609.9s | Verified, 684.1s | 173.9s / 130.4s | 1,312 |

The 28-layer smoke probe decoded at 8.1–8.4 tok/s, but actual agent-turn speeds
were lower as context grew (fix: 4.4–6.2 tok/s). Do not substitute short-prompt
throughput for task latency. No claim of statistical reliability or maximum tuning.

Low-effort comparison at the same 28-layer split failed both tasks (67.1s fix,
90.6s understanding, measured prefill 57.2s / 70.0s). No patch or final explanation
was produced. Raw SSE preserves `<ifm|tool_calls>` within the reasoning channel;
this is a compatibility failure, not evidence of weak reasoning or faster completion.

Further fixed-request diagnostics (1,672 uncached prompt tokens, two requests each):

| GPU layers / KV / flash attention | Prefill seconds | Decode tok/s |
| --- | ---: | ---: |
| 28 / f16 / off | 58.0 / 58.1 | 6.61–6.66 |
| 28 / f16 / on | 61.3 / 61.5 | 6.52–6.53 |
| 28 / Q8 / on | 57.3 / 57.5 | 5.79–5.80 |
| 36 / Q8 / on | 52.0 / 51.5 | 6.85–6.91 |

The Q8/36-layer profile's first agent repetition did not establish a better choice:
bug fix verified in 694.0s (151.9s prefill), understanding partial in 567.6s
(109.7s prefill), with incorrect current-code zero/one-retry attempt counts.
Minimum free VRAM was 1,627 MiB. Seed43 passed both tasks: fix 497.7s
(136.6s prefill), understanding 658.1s (112.4s prefill). The f16/28-layer repeat
passed fix in 752.5s (183.8s prefill), but its 670.2s understanding answer
(119.9s prefill) invented an immutable dataclass. No quality difference can be
attributed specifically to quantization from these small samples.

Matched two-task/two-seed comparison, including unsuccessful answers in elapsed time:

| Profile | Verified / attempts | Total agent wall | Verified tasks/hour | Total measured prefill | Minimum free MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| f16 / 28 GPU / flash off / high | 3/4 | 2,716.6s | 3.98 | 608.0s | 1,312 |
| Q8 / 36 GPU / flash on / high | 3/4 | 2,417.4s | 4.47 | 510.6s | 1,620 |

Q8/36 is the provisional choice for about 11% less total wall time and better
observed headroom at equal verified counts. Desktop load and generation variance
remain confounders; this is not statistical confidence or a universal quality claim.
Research, implementation, and recovery tests below are not part of the matched
rates above. Earlier failures and environment errors remain
in the artifact ledger and are not erased by this profile selection.

Broader selected-profile validation, first repetition (seed42):

| Task | Result | Agent wall | Measured prefill | Minimum free MiB |
| --- | --- | ---: | ---: | ---: |
| Research, synthetic documents | Verified; resolving citations, injection ignored | 445.7s | 83.8s | 1,627 |
| Multi-file implementation | Timeout; behavior checks passed but required tests not added | 900.1s | At least 107.3s | 1,627 |
| Recovery | Verified; stale command diagnosed, validation fixed and regression added | 573.1s | 138.3s | 1,296 |

Final seed43 repeats: recovery verified in **621.4s** (140.4s prefill), but
implementation was resource-blocked after **360.9s** at **980 MiB free**, and
research after **78.6s** at **1,018 MiB free**. The 1,024 MiB guard stopped them
and unloaded the worker; no ordinary desktop applications were killed.

### Initial tuning-pass outcome

The selected Q8/36-layer/high-effort profile has **6/10 verified attempts** across
five frozen tasks, two seeds each:

| Task | Verified | Other outcomes |
| --- | ---: | --- |
| Bug fix | 2/2 | — |
| Understanding | 1/2 | Incorrect current-code boundary table |
| Research | 1/2 | One resource-blocked attempt |
| Implementation | 0/2 | One timeout, one resource-blocked attempt |
| Recovery | 2/2 | — |

Total task wall time including failures/stops: **5,397.1s**; **4.00 verified
tasks/hour**, excluding model loading and evaluator overhead. Successful-task
median **597.2s**, range **445.7–694.0s**. Total measured prefill is **at least
1,107.3s**; unfinished turns have unknown timing. Successful trials retained at
least **1,102 MiB free**, but two later trials crossed the approved reserve, so
this profile is **conditional on desktop GPU load**, not universally memory-safe.
The benchmark guard is not a production-wide GPU reservation.

This concludes the initial tuning pass, not proof of maximum performance or
statistical reliability. A quiet-window repeat or a separately tested more
conservative placement is needed to resolve the blocked categories. The
implementation timeout is not counted as completion merely because unfinished
production code passed hidden behavior checks. Results and all previous attempts
are retained in `~/.cache/local-k2-tuning-20261018/summary.json`, `reviews.json`,
the trial ledger, manifests, telemetry, and transcripts. No benchmark is left running.

### Follow-up 10 tok/s experiments

The user explicitly requested a 10 decode tok/s target after the initial pass.
The MoVA follow-up holds 16K context, Q8 KV, flash attention, 36 GPU layers,
high reasoning, and batch threads6 fixed. Two uncached requests per profile use
the same captured 1,672-token agent prompt and naturally generate 71 tokens:

| Change | Decode tok/s | Prefill seconds |
| --- | ---: | ---: |
| Six-thread control, first | 6.90–6.98 | 50.6–50.7 |
| Four generation threads | 6.04–6.52 | 56.7–59.5 |
| Two generation threads | 4.40–4.52 | 59.0 |
| Eight generation threads | 6.50–6.52 | 55.7–55.8 |
| Six physical cores pinned | 6.42–6.90 | 56.5–58.0 |
| Non-mapped `load-mode=none` | 6.34–6.45 | 35.1–35.2 |
| Six-thread control, repeated | 6.35–6.39 | 58.6 |
| One GPU expert block (`n-cpu-moe=47`) | 6.37–6.42 | 53.9–54.2 |

No configuration reached 10 tok/s on this fixed prompt. Repeated-control drift
prevents interpreting small differences as reliable wins. Non-mapped loading
improved prefill materially, but increased loading to 55s and has not been
validated in agent tasks. The GPU expert trial retained only 1,147 MiB free and
did not improve decode enough to promote. Deployed MoVA settings are unchanged.

A longer standalone coding-request diagnostic (485 prompt tokens, 512 generated
tokens at the ceiling; not an agent completion) decoded at **7.41 tok/s** normally,
**7.75 tok/s** with n-gram speculation (60 of 119 proposed draft tokens accepted),
and **7.33 tok/s** with non-mapped loading. None reached 10 tok/s. At the larger
1,672-token agent prompt, n-gram speculation stayed at **6.28–6.40 tok/s**.

The 7B medium-effort smoke reproduced the generic reasoning-closer mismatch:
literal tool calls remained in `reasoning_content`. This matches upstream
[issue #30246](https://github.com/ggml-org/llama.cpp/issues/30246). The runtime
package now pins the unmerged [PR #30335](https://github.com/ggml-org/llama.cpp/pull/30335)
fix at commit `406bd24fe19818796bbf4ceed4828ad2482f934a`, with its two parser
regression tests. The patch accepts the generic `</ifm|think>` closer at medium/
low effort without changing high-effort parsing. It applied cleanly to b11454;
build and runtime validation are pending. All pre-fix medium/low failures remain
separate compatibility tracks, not evidence about intrinsic reasoning capability.

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
