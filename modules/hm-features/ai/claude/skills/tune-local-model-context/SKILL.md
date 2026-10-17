---
name: tune-local-model-context
description: Find the largest usable context for local llama.cpp/GGUF models while retaining a minimum generation tokens-per-second rate and VRAM headroom. Use when asked to increase context, tune local or abliterated models, repeat a context/rebuild/benchmark sweep, or retune capcuDell's Qwen models after hardware or runtime changes. Defaults to at least 15 decode tok/s; distinguishes long-context speed from short-prompt speed and prompt-processing latency.
---

# Tune local model context

Find the largest **tested passing** context per model. Use an adaptive
edit → format → rebuild → measure → adjust loop, then restore and activate
the best passing settings. A configured context is not evidence that a
near-full context is fast enough.

## Scope and defaults

- Use the host, model subset, speed floor, and memory reserve the user gives.
  For the CapCUDell workflow, default to 15 generation tok/s and the existing
  1,536 MiB free-VRAM reserve. Discover model IDs; do not assume four forever.
- Treat the target as **decode speed**, excluding prefill and model loading.
  Explain this distinction. If the user means end-to-end speed, establish
  prompt/output sizes and use wall-clock throughput instead.
- An explicit request to tune and rebuild authorizes that loop on the named
  host, not unrelated configuration changes. For a plan, dry run, analysis of
  existing results, or a request to create this skill, do not activate changes
  or run inference. Ask before activation if it was not authorized.
- Keep model revision, quantization, KV-cache precision, threads, CPU-expert
  placement, output budget, and safety reserve fixed. Tuning those is a
  separate experiment requiring user agreement.
- Read `references/capcudell.md` for repository paths, commands, historical
  results, and the known expert-placement/fitting limitation. Those results
  are starting hints, not fresh measurements.

## 1. Inspect and establish a baseline

1. Read applicable `AGENTS.md` instructions and inspect Git status, including
   staged changes. Preserve work from other sessions; never reset the tree.
2. Verify the actual hostname, GPU/driver/VRAM, RAM/swap, current backend,
   model IDs and pinned artifacts, runtime package/version, per-model context,
   expert placement, fit floor, client limits, and competing GPU services.
   Inspect `type nr` before using it; never rebuild the wrong host.
3. Find each model's native context from loaded metadata/model documentation.
   Do not invent a limit or exceed it by enabling unrequested RoPE scaling.
4. Record the initial settings and per-model last-known-good candidates. Run
   a baseline if no comparable current measurement exists. If baseline fails,
   first find a passing smaller context or report that the speed floor cannot
   be met; increasing context cannot be assumed to fix it.
5. Create a fresh run directory such as
   `~/.cache/qwen-context-tuning-YYYYMMDD-HHMMSS/`. Save hardware/runtime details,
   candidate settings, rebuild exit codes/logs, raw timing JSON, VRAM snapshots,
   and failure reasons there. Avoid overwriting earlier runs or logging secrets.

Use one benchmark process and one resident model at a time on a shared GPU.
Do not kill unrelated applications to improve results. If another client is
actively generating, coordinate a quiet window rather than interrupting it.
Keep normal desktop load comparable throughout the sweep.

## 2. Search each model independently

Start near its current context. With ample speed/memory margin, increase by
roughly 1.5–2×, capped at the native limit. Near a boundary, use smaller aligned
steps. Once a candidate fails, bracket the last pass and first fail and test
between them; do not continue increasing a failing candidate.

Reasonable finishing resolutions are about 2,048 tokens for a 40K dense
profile, 4,096 for a memory-limited MoE profile, and 8,192 for a 240K profile.
Adapt these to hardware and cost. Context fitting can abruptly spill layers
to CPU, so do not extrapolate speed linearly or claim an exact theoretical
maximum. Stop at the native limit or a sufficiently narrow tested bracket.

For **every changed candidate**:

1. Change only that model's declarative context override, ensuring runtime
   `ctx-size`, non-shrinking `fit-ctx`, and client context limits remain aligned.
   Add per-model support if absent; do not force all models to share the
   weakest model's limit. Preserve default and bootstrap host composition.
2. Format only affected Nix files with `nix fmt -- <paths>`. Run `nr` on the
   confirmed host and save its log and exit status. Do not benchmark a stale
   service after a failed build/switch.
3. Verify API readiness and the effective worker arguments/loaded `n_ctx`.
   A successful build or advertised catalog entry alone proves neither
   activation nor that fitting kept the requested context.
4. Warm the selected model and optionally screen it with a short prompt.
   Exclude loading/warm-up from timings. Reject a short-prompt speed failure
   early, but never accept a candidate based only on a short prompt.
5. Capture `nvidia-smi` **memory.free** while that model is loaded, before
   switching models. Do not infer free VRAM as total minus used: reserved
   memory makes that inaccurate. Reject insufficient headroom before spending
   time processing a long prompt. Also inspect available RAM and allocation
   failures; do not compensate with swapping or reduced safety headroom.
6. Test an uncached near-full prompt, leaving explicit output space. With the
   existing benchmark, use input = context − 768, 256 generated tokens for
   exploratory trials, and 512 for final validation. Use exact token counts
   from that model's tokenizer, not characters or paragraph estimates.
7. Verify every requested input token was evaluated, output completed, and no
   truncation/context shift or cached-prefix prefill occurred. Save raw server
   timings, prefill time, and wall time separately. Inspect free VRAM again
   after the long request while the same model remains resident.
8. Classify the trial as speed failure, memory/headroom failure, load failure,
   invalid measurement, or pass. Update its bracket and last-good context.
   A different model's faster result cannot offset this model's failure.

On CapCUDell, representative commands from the repository root are:

```sh
# Set these for each candidate; use distinct log paths for every trial.
MODEL=qwen3.8-27b-abliterated
CONTEXT=45056
INPUT=$((CONTEXT - 768))
nr > "$RUN/rebuild.log" 2>&1
# Check the rebuild's exit status before proceeding.
local-qwen-bench --model "$MODEL" --runs 1 --tokens 256 \
  --json "$RUN/short.json"
nvidia-smi --query-gpu=timestamp,memory.total,memory.used,memory.free --format=csv
local-qwen-bench --model "$MODEL" --runs 1 --tokens 256 \
  --prompt-tokens "$INPUT" --json "$RUN/long.json"
```

Do not blindly chain commands through failures. The benchmark can exit 1 for
either a below-target result or an API/load error, and an interrupted batch
may never write its JSON. Preserve stdout/stderr and inspect both the result
file and service logs before classifying it.

Long prefill can take many minutes. Estimate its cost from measured prefill
speed; screen expensive candidates before final repeats. If using background
tools, wait for completion notifications instead of polling. Do not rebuild,
edit the active trial configuration, or start another GPU workload mid-trial.

## 3. Validate and select the final settings

For each model, run **at least two independent near-full prompts with 512
generated tokens** at its best candidate. Every raw sample's
`predicted_per_second` must meet the floor. An aggregate above 15 can hide a
14 tok/s run, and the existing benchmark's aggregate uses a slightly different
token-count convention from the raw server rate. Prefer the conservative raw
per-run measurement for acceptance. Reject incomplete, truncated, cached,
non-finite, or mismatched samples even if their speed looks excellent.

Use the bundled offline checker to apply these rules to existing benchmark
JSON. Supply actual loaded-model VRAM readings, not placeholders:

```sh
python3 <skill-dir>/scripts/check_trial.py "$RUN/validation.json" \
  --model "$MODEL" --context "$CONTEXT" --target 15 \
  --minimum-free-mib 1536 --free-before-mib 1700 --free-after-mib 1680
```

Replace `<skill-dir>` with this skill's base directory. The example VRAM
numbers are illustrative. The checker does not run inference, rebuild,
verify activation, or prove model quality. It defaults to two 512-token runs
at context − 768 input tokens; use `--min-runs 1 --min-generated 256` for an
exploratory result. It returns 0 for a pass, 1 for a rejected trial, and 2 for
malformed input. Inspect its reasons rather than trusting exit status alone.

If validation fails, lower the context and repeat. For near-threshold or
highly variable results, add runs or select a lower stable context. A candidate
that fails the memory reserve is not acceptable merely because decode is fast.

## 4. Restore, activate, verify, and report

1. Restore every model to its best validated passing context, not the last
   attempted value. If a model has no pass, preserve/restore its starting
   setting and explicitly report it as unvalidated or below target.
2. Format the changed files, run relevant offline tests, and perform the final
   authorized `nr`. Diagnose activation failures before claiming completion.
   A competing Ollama restart can interrupt this router during activation;
   inspect logs and recover only the intended backend, then retry the switch
   if appropriate. Do not disable unrelated services permanently.
3. Check API readiness, active services, actual `ctx-size` and `fit-ctx`, and
   loaded `n_ctx` where available. Compare them with the generated OpenCode
   `providers.local-qwen.models.<id>.limit.context` and Hermes default/model
   limits. Load the OpenCode skill before changing its configuration shape.
4. Run a final short smoke test for each model on the activated configuration.
   It supplements, not replaces, the earlier near-full validation. If model
   weights/runtime/placement changed meanwhile, repeat the long validation.
5. Save a machine-readable final summary and update the backend's tuning
   notes: exact context/input/output tokens, all validation rates, worst rate,
   headroom, failure brackets, hardware/runtime, and raw-result locations.
6. Report a compact table: model, final context tokens, lowest validated
   generation tok/s. State whether activation succeeded, distinguish memory
   limits from speed limits, and remind the user that decode excludes prefill.

Describe these as the largest **tested operating points**, not universal
maxima. Repeated synthetic text is a throughput test, not evidence of long-
context recall, tool-use correctness, vision quality, or concurrent-client
performance. If the user stops the sweep, restore last-good settings within
the existing authorization and clearly identify unfinished validation.
