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
sudo nixos-rebuild switch --flake "path:/home/vir/dotfiles-nix#nodename"

gopass clone vps:~/git-repos/pass
# if gpg needs to be restarted after switch
gpgconf --kill gpg-agent
gpg-agent --daemon
```

# First time setup notes
1. first time setup may require setting vir password from root account with passwd
2. you also might have to ssh into predefined ssh hosts to add them to known hosts
