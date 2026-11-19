{ ... }:
{
  flake.nixosModules.packageUsage =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      packageRows =
        scope: extraOutputs: packages:
        map (
          pkg:
          let
            outputs =
              if pkg.outputSpecified or false then
                [ pkg ]
              else
                map (name: pkg.${name}) (pkg.meta.outputsToInstall or [ (pkg.outputName or "out") ]);
          in
          {
            inherit scope;
            name = lib.getName pkg;
            paths = lib.unique (
              map toString (
                outputs ++ lib.concatMap (name: lib.optional (pkg ? ${name}) pkg.${name}) extraOutputs
              )
            );
          }
        ) (builtins.filter (pkg: lib.getName pkg != "nix-package-usage") packages);

      manifest = pkgs.writeText "nix-package-usage.json" (
        builtins.unsafeDiscardStringContext (
          builtins.toJSON (
            packageRows "system" config.environment.extraOutputsToInstall config.environment.systemPackages
            ++ lib.concatLists (
              lib.mapAttrsToList (user: hm: packageRows "home:${user}" [ ] hm.home.packages) (
                config.home-manager.users or { }
              )
            )
          )
        )
      );
      command = pkgs.writeShellScriptBin "nix-package-usage" ''
        exec ${lib.getExe pkgs.python3} -I ${./package-usage/tracker.py} \
          --manifest ${manifest} "$@"
      '';
    in
    {
      environment.systemPackages = [ command ];
      systemd.services.nix-package-usage = {
        description = "Record execution counts for Nix store programs";
        wantedBy = [ "multi-user.target" ];
        before = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe command} collect";
          StateDirectory = "nix-package-usage";
          StateDirectoryMode = "0700";
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = "5s";
          NoNewPrivileges = true;
          CapabilityBoundingSet = [
            "CAP_SYS_ADMIN"
            "CAP_SYS_PTRACE"
            "CAP_DAC_READ_SEARCH"
          ];
        };
      };
    };
}
