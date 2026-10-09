{ ... }:
{
  flake.nixosModules.nixPolicy =
    { config, lib, ... }:
    let
      profileUsers = lib.filter (user: builtins.hasAttr user config.users.users) [
        "vir"
        "capcu"
      ];
    in
    {
      nixpkgs.config.allowUnfree = true;
      nix.settings = {
        trusted-users = [ "root" ] ++ profileUsers;
        experimental-features = [
          "nix-command"
          "flakes"
          "wasm-builtin"
          "parallel-eval"
        ];
        max-jobs = "auto";
        auto-optimise-store = true;
        http-connections = 50;
        connect-timeout = 5;
        fallback = true;
        builders-use-substitutes = true;
        extra-substituters = [ "https://cache.numtide.com" ];
        extra-trusted-public-keys = [
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };
}
