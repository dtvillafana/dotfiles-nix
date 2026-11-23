# Inkling 2 Mini on rogdesktop

`localModelsPascal` selects `localModelsInkling`; no other host selects it.
Discovery defines the feature without activating it globally. Both normal and
bootstrap rogdesktop configurations include it.

## Artifacts and isolation

- Model: `onemunanoyo/Inkling-2-Mini-Abliterated-Balanced-GGUF`,
  revision `ce0157864e970352f6ba33e8a781446b9b26ec99`, `UD-Q3_K_XL`
  (13,631,778,016 bytes). The host profile pins its SHA-256.
- Runtime: Unsloth `b12649-mix-c7059d6`, merged tree
  `189f431bf58f433d376d718c7788b1bf4467fa72`, pinned by `flake.lock`.
  **Use the merged source release asset, not GitHub's source archive for the
  tag.** The latter lacks the additional Inkling implementation.
- CUDA 12, SM 6.1, CPU architecture dispatch, API-only build (no npm/downloaded
  web assets). CUDA 13 cannot target the GTX 1070.
- Text and tool calls only; no projector or speculative drafter is downloaded.
  Abliteration benchmarks do not establish coding or tool-use reliability.

Inkling has a separate worker and OpenCode provider so updating it does not
replace the existing Qwen/K2 runtimes, pins, presets or default model.
`local-inkling.service` conflicts with `local-models.service` and its competing
backend services: only one backend owns the GPU. Switching providers stops the
other backend; do not switch during another client's generation. Hermes stays
on its existing provider and can reactivate that backend.

## Placement

See `../local-models-pascal.nix` for the current physical CPU-expert layer list.
All attention and non-expert block weights are GPU-preferred. Expert weights
matched by `override-tensor` stay in system RAM and execute on CPU, not through
VRAM oversubscription. Physical layers 6–17 execute three times per token, so
GPU placement there avoids more CPU work than the same placement outside the
loop. Every GPU expert block in this quant is roughly 547 MiB.

The starting profile keeps every expert block on CPU until hardware validation.
It uses six CPU threads, one slot, a 16,384-token context and F16 K/V caches.
Fitting is explicitly disabled: automatic fitting is not a headroom guarantee
with expert overrides. Preserve at least 1,536 MiB free VRAM during validation,
including prefill. The service disables swap. Do not infer actual allocation
from the offloaded-layer count; inspect the CUDA/CPU buffer sizes in its log.

## Evaluate, activate and use

```sh
nix eval "path:$PWD#nixosConfigurations.rogdesktop.config.system.build.toplevel.drvPath"
nix eval "path:$PWD#nixosConfigurations.rogdesktopBootstrap.config.system.build.toplevel.drvPath"
# Evaluate before switching; this also downloads the pinned model/runtime.
nr
```

Only `local-inkling-proxy.socket` starts at boot. Its first connection starts
the worker and waits for `/health` before forwarding traffic. API endpoint:
`http://127.0.0.1:18084/v1`. It is loopback-only, without authentication for
other local users.

Select `local-inkling/inkling-2-mini-abliterated` in OpenCode's `/models`.
The context and 8,192-token output limit are shared with the worker
configuration. Sampling is temperature 1, top-p 1, top-k 0, min-p 0, with the
model's high reasoning effort; long thinking can delay the final answer.

```sh
systemctl status local-inkling-proxy.socket local-inkling
journalctl -u local-inkling -b --no-pager
nvidia-smi
```

To free its resources without automatically restarting it:

```sh
sudo systemctl stop local-inkling-proxy.socket local-inkling-proxy.service local-inkling.service
# Re-enable on-demand use:
sudo systemctl start local-inkling-proxy.socket
```

## Sources

- [Balanced model card](https://huggingface.co/onemunanoyo/Inkling-2-Mini-Abliterated-Balanced-GGUF)
- [Unsloth runtime and sampling guide](https://unsloth.ai/docs/models/inkling-2-mini)
- [Pinned runtime release](https://github.com/unslothai/llama.cpp/releases/tag/b12649-mix-c7059d6)
