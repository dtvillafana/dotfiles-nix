# Rogdesktop agentic experiments (started 2026-10-17)

**In progress. These are not final optimized profiles or broad capability scores.**
The host-selected configuration is `../local-qwen-pascal.nix`; historical synthetic
context/decode measurements in [README.md](README.md) do not validate the new
agentic profiles. The goal is verified task completion per elapsed time, not a
15 token/s or 90% GPU-utilization gate. The benchmark free-VRAM reserve is now
**1,024 MiB**, explicitly approved by the user after the resumed 27B trial was
blocked at 1,503 MiB. Earlier trials used 1,536 MiB; their outcomes remain unchanged.
This changes the benchmark stop threshold, not automatic fitting or placement.

## Harness and scope

- Real OpenCode V2 2.0.30 `run --standalone` sessions with a dedicated, compact
  benchmark-agent system prompt and equal tools/permissions across candidates.
  This is not the full daily global MCP/tool configuration.
- Bubblewrap filesystem/PID/network namespaces, disposable dependency-free Python
  fixtures, isolated home/configuration, and a model-only Unix-socket relay.
  Candidate agents cannot access the actual home, other trials, or hidden judge.
- Five frozen task briefs: code understanding, retry bug fix with regression test,
  multi-file API implementation, recovery from a stale test command plus a
  validation fix, and source-grounded research with a harmless injection fixture.
- Research uses explicitly synthetic local documents, not live web search.
- Per-task caps: 900 seconds, 40 tool calls, 8,192 total generated tokens; natural
  termination. Early trials had a 16-step harness cap; subsequent tracks use 40
  steps and are kept separate. Normal desktop applications remain open.
- Task wall time includes prefill, reasoning, generation, tool execution, and
  retries. Model loading/warming and independent evaluator time are separate.
  Prefill totals are measured per turn from server timings; incomplete turns
  have unknown timing/usage, not invented estimates.
- Hidden checks reject seeded bugs and accept known-good implementations before
  inference. A candidate's new regression must fail on the original code, existing
  tests must remain intact, and both public and hidden checks must pass. Manual
  scope/citation/safety review is required before counting verified completion.

## Recorded comparisons so far

All times exclude model loading. These are individual small-fixture trials,
not claims about arbitrary coding tasks or statistical reliability.

| Track/model | Task | Agent wall time | Measured prefill | Result |
| --- | --- | ---: | ---: | --- |
| Initial 9B | Bug fix | 71s / 5s, stopped | Incomplete | Resource-blocked as desktop VRAM use grew |
| Initial MoE | Bug fix | Not started | — | Only 1,142 MiB free after load; rejected |
| Initial 27B, automatic whole-layer split | Bug fix | 900s | At least 110s | Timeout, no correct patch |
| 9B, extra fitting headroom, greedy | Bug fix | 673s | 156s | Production fix correct, regression remained failing; token budget exhausted |
| MoE, 36 CPU expert layers, greedy | Bug fix | 210s / 223s | 97s / 107s | **Two reviewed unassisted successes**, meaningful failing-before/passing-after regression |
| MoE, same split | Understanding | 523s | 133s | **Reviewed unassisted success**, resolving citations and correct retry boundaries |
| 27B, whole-layer split, low reasoning effort | Bug fix / understanding | 900s / 900s | At least 122s / 89s | Both timed out |
| 9B, temperature 1, extra fitting headroom | Bug fix | 578s | 30s | Token budget exhausted; production/regression checks failed |
| 27B, 36 GPU layers + 60 CPU FFN layers, low effort | Bug fix | 900s | At least 138s | Correct patch and valid regression pass public/hidden checks, but agent did not finish before deadline; **still a timeout** |

The greedy 9B repeatedly returned a `RuntimeError` object rather than raising it
inside its test handler, then made ineffective repairs. Neither higher token
throughput nor a larger step allowance fixed that capability failure. Its deployed
temperature-1 sampler also failed this task; those runs are not successes merely
because the original production bug was sometimes fixed.

The 27B's template defaults to `xhigh` reasoning. Lowering it to `low` alone did
not complete the tasks. Reworking tensor placement did produce a correct tested
patch under the same task brief; final-response/reasoning time still exceeded the
budget. Non-thinking mode is the next explicit experiment, not yet a recommendation.

## Placement evidence and current experiments

Verbose load logs verify allocation rather than trusting requested layer counts:

- 9B with a 2,304 MiB fitting target loaded **30/33 layers on GPU**, with about
  947 MiB CPU-mapped weights, 4,409 MiB CUDA weights, and 512 MiB CUDA KV cache.
  Agent trials retained at least 2,354 MiB free after this adjustment.
- MoE with `n-cpu-moe=36` reports all attention/recurrent layers offloaded, but
  experts for the first 36 blocks remain CPU-resident. Load logs showed about
  17,688 MiB CPU-mapped weights, 3,295 MiB CUDA weights, and 680 MiB CUDA KV.
  Its reviewed trials retained at least 3,012 MiB free. Testing `n-cpu-moe=35`
  adds one GPU expert layer while retaining the starting 65,536 context.
- 27B automatic fitting loaded **18/66 layers on GPU**, about 10,664 MiB CPU-mapped
  weights, 4,775 MiB CUDA weights, and 1,536/512 MiB CPU/CUDA KV at 32K context.
- Explicit `gpuLayers=36`, `cpuFfnLayers=48` failed allocation at the CUDA compute
  buffer; using 56 CPU FFN layers loaded but left only **1,268 MiB free** and was
  rejected. With 60 CPU FFN layers, the actual agent trial retained **1,938 MiB**
  minimum free. Automatic fitting is disabled for these explicit split trials.
- Contexts remain 16,384 / 65,536 / 32,768 for 9B / MoE / 27B. Request-body
  controls are propagated into each OpenCode model entry, and captured upstream
  requests verify the sampler/template kwargs actually reached llama.cpp.

Candidate 003 tests non-thinking mode for 9B and 27B and one extra GPU expert
layer for MoE. It repeats the frozen tasks without changing checks or coaching
the models. Safe settings may still be nonqualifying for particular tasks.

## Artifacts and limitations

Raw data and the experimental runner are in
`~/.cache/local-agent-benchmark-20261017-215148/`: frozen fixtures/judge preflight,
versioned manifests, trial ledger, OpenCode JSONL events, request/response SSE,
per-turn timing/usage, GPU/RAM samples, independent test outputs, manual reviews,
load-placement logs, rebuild exit codes/logs, and provisional `summary.json`.
The runner is an experimental local artifact, not an installed repository CLI.

Runner failures are recorded separately: an overlong Unix-socket path prevented
one candidate from starting; one interrupted 9B understanding attempt had no
persisted final timing, so its duration/completion is unknown. Neither is graded
as a model-quality failure. Earlier attempts remain in the ledger; tracks with
different harness settings or desktop load must not be pooled into one score.

Activation can race with conflicting Nemotron/Ollama startup. Failed switches
were diagnosed, the intended Qwen router recovered, and `nr` retried before
benchmarking. No competing backend was permanently disabled or removed.
