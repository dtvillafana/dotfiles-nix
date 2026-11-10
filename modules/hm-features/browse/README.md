# Anomaly Browse

The `ai` Home Manager feature imports `browse`, which installs the pinned Browse
CLI, declares its Brave and Chromium extensions, and configures the OpenCode and Claude MCP
servers. Discovering this feature does not activate it. Vimium and unrelated
browser extensions are unchanged.

## First use

1. Evaluate and rebuild your usual host configuration, then reopen Brave and
   approve the **Browse** extension if prompted. Its store page is
   <https://chromewebstore.google.com/detail/mfnicocicmmlkpjnaffgihfjhdgjkdjg>.
2. Remove the old **Open Browser Use** extension in Brave if it remains installed;
   removing its external-install declaration does not necessarily uninstall an
   already accepted extension. Its native-messaging manifests are no longer managed.
3. Run `browse pair`. In Browse's extension options, choose **Pair with a code**
   (under advanced), enter the printed code, and connect. Pairing is private,
   per-user runtime state, not a Nix-managed secret.
4. Run `browse doctor` and `browse status` to verify the connection. OpenCode
   reloads its configuration automatically; `/mcps` shows the `browse` server.

Do not run `browse install` to rewrite the Nix-managed agent configuration. No
remote-debugging port, separate automation profile, native-messaging host, or
always-running system service is needed. Browse starts its local relay on demand.
Existing automation-profile data is left untouched.

## Updates

The CLI is currently packaged for `x86_64-linux`. Its npm tarball is pinned by
`browse-cli-src` in `flake.nix` and hashed in `flake.lock`; update that URL and the
version in `packages/browse.nix` together, then run `nix flake lock` and build
`.#browse`. The ELF fixup hook comes from the already-pinned `llm-agents` input
and preserves the Bun executable's embedded payload.

The CLI wrapper disables upstream self-updates so Nix remains its owner. The
Chrome Web Store updates the extension independently. Do not use `browse update`
or the upstream shell/npm installer to replace the Nix-managed CLI.

Run `browse skill` for the upstream agent reference. Agents use their own Browse
sessions, inspect before acting, and hand human-only steps back with `handoff()`.
