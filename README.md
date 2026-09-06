# nixos-configs

These are David's nixos configs

# Fresh installation

Use the bootstrap variant of the matching host configuration for the first switch. It contains the
normal system and home configuration, but omits SOPS secrets and features that require them.

```bash
sudo nixos-rebuild switch \
  --flake "github:dtvillafana/dotfiles-nix#nodenameBootstrap" \
  --extra-experimental-features "nix-command flakes"
```

Available bootstrap configurations are `rogdesktopBootstrap`, `capcuDellBootstrap`,
`thinkpadBootstrap`, `hpenvynixBootstrap`, and `cap765Bootstrap`.

Set the profile user's password if needed, then install the existing recipient SSH private key at
`/home/USERNAME/.ssh/id_ed25519`. The key must be owned by that user and have mode `0600`. A newly
generated key cannot decrypt the existing secrets until the secrets are re-encrypted for it.

Switch to the normal configuration after the required keys are installed:

```bash
sudo nixos-rebuild switch --flake "github:dtvillafana/dotfiles-nix#nodename"
```

For a local checkout, use `path:/home/vir/git-repos/dotfiles-nix` instead of the GitHub flake URL.

# Additional setup

`~/.config/sops/age/keys.txt` may be populated from gopass for interactive SOPS use. NixOS secret
activation uses `/home/USERNAME/.ssh/id_ed25519`.

```bash
gopass clone vps:~/git-repos/pass
# If gpg needs to be restarted after switching:
gpgconf --kill gpg-agent
gpg-agent --daemon
```

# First time setup notes

1. First-time setup may require setting the profile user's password from the root account with `passwd`.
2. You may have to connect to predefined SSH hosts to add them to `known_hosts`.
