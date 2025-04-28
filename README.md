# nixos-configs
These are David's nixos configs
# additional setup
put the age secret key at (can be retrieved from gopass)
```nix
~/.config/sops/age/keys.txt
```


replace nodename with your nodes name
```bash
sudo nixos-rebuild switch --flake github:dtvillafana/dotfiles-nix#nodename
# or if cloned locally
sudo nixos-rebuild switch --flake "path:/home/vir/dotfiles-nix#nodename" --impure

gopass clone vps:~/git-repos/pass
# if gpg needs to be restarted after switch
gpgconf --kill gpg-agent
gpg-agent --daemon
```
