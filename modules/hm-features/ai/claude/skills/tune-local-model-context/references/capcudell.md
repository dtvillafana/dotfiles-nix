# CapCUDell reference

Read the current files before changing anything; these paths and results were
observed on 2026-10-16 and can change.

## Configuration and tools

Repository: `~/git-repos/dotfiles-nix`.

- `modules/features/local-models-blackwell.nix`: host-selected Blackwell profile;
  `services.local-models.modelOverrides.<id>.contextSize` is the per-model knob.
- `modules/features/local-models.nix`: shared runtime presets and OpenCode limits;
  per-model overrides set both `ctx-size` and `fit-ctx`.
- `modules/hosts/capcuDell/configuration.nix`: Hermes default context comes
  from its selected default model's provider limit; custom models use each
  provider model's own limit. Do not replace these with the shared fallback.
- `modules/features/local-models/benchmark.py`: installed as `local-models-bench`;
  use `--model`, `--runs`, `--tokens`, `--prompt-tokens`, and `--json`.
- `modules/features/local-models/test_benchmark.py`: offline regression tests.
- `modules/features/local-models/BLACKWELL.md`: detailed measurements and caveats.

`type nr` previously expanded to:

```sh
nixos-rebuild switch --flake "path:/home/capcu/git-repos/dotfiles-nix#capcuDell" \
  --sudo --no-reexec --no-update-lock-file --no-write-lock-file
```

The `path:` flake includes untracked files without staging. Do not stage,
commit, update the lock, or revert user changes just to run a trial. The
profile is used by both normal and bootstrap CapCUDell configurations; shared
module changes also affect other hosts. Respect their placement defaults.

The loopback router is `http://127.0.0.1:18082`, proxied to port 18083.
`GET /models` exposes worker status/arguments and loaded-model metadata;
`GET /v1/models` lists model IDs. One model is resident at a time. The first
API connection can activate the router and stop competing Ollama services.
Do not stop Hermes or OpenCode: they are clients of this backend.

Inspect status/errors with `systemctl show local-models -p ExecStart -p ActiveState`
and `journalctl -u local-models -b --no-pager`. A build can finish but activation
fail if a competing Ollama startup terminates the router. Restore API readiness
and verify the actual service after any rebuild; do not mask a failed switch.

## Hardware and the important fitting exception

Observed hardware: RTX PRO 2000 Blackwell, 16,311 MiB VRAM; Core Ultra 7 265K;
62 GiB usable system RAM, no swap. The tested profile used CUDA 13, F16 KV
caches, flash attention, eight threads, one slot, 20/40 MoE CPU-expert layers,
and a 1,536 MiB fit target.

The locked llama.cpp runtime **cannot auto-fit when CPU-expert tensor overrides
are already set**. In that case `fit-target` is not a reliable memory guard.
Inspect actual free VRAM. Do not assume an OOM will trigger layer offloading
or silently reduce context. A 262,144-token MoE trial failed to allocate its
5,120 MiB KV cache. This exception is why the MoE result was memory-limited.

## Historical validated points (not promises for the next run)

| Model ID | Context | Input | Two raw decode rates (tok/s) |
| --- | ---: | ---: | ---: |
| qwen3.8-27b-abliterated | 45,056 | 44,288 | 15.78 / 15.83 |
| qwen3.8-27b-coder390-abliterated | 45,056 | 44,288 | 16.06 / 16.05 |
| qwen3.5-9b-abliterated | 245,760 | 244,992 | 16.52 / 16.53 |
| qwen3.6-35b-a3b-abliterated | 143,360 | 142,592 | 30.68 / 31.01 |

Each validation generated 512 tokens twice. The next tested dense increment,
47,104, fell below 15 tok/s for both 27B models. The 9B failed at 253,952.
MoE at 143,360 retained 1,596 MiB free before and after long prompts; the next
4,096-token increment left only 1,516 MiB, below the reserve. A 196,608-token
MoE could decode short prompts quickly but left only 550 MiB free.

Raw original results: `~/.cache/qwen-context-tuning-20261016/`. Do not overwrite
them. Different desktop load, runtime builds, or weights invalidate direct
comparison. Long MoE prefill took many minutes, even when decode was fast.
