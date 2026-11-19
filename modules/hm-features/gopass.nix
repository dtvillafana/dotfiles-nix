{ ... }:
{
  flake.homeModules.gopass =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [
        (pkgs.gopass.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./gopass/no-decrypt-diffs.patch ];
        }))
      ];

      # The store's local Git config takes precedence over Home Manager's Git config.
      # Remove only the converter installed by gopass, not custom diff settings.
      home.activation.removeGopassDiffDecrypt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        store=${lib.escapeShellArg "${config.xdg.dataHome}/gopass/stores/root"}
        if [[ -e "$store/.git" ]]; then
          run ${lib.getExe pkgs.git} -C "$store" config --local --fixed-value --unset-all \
            diff.gpg.textconv 'gpg --no-tty --decrypt' || {
            status=$?
            # Git exits 5 when there is no matching setting.
            if [[ "$status" != 5 ]]; then
              exit "$status"
            fi
          }
        fi
      '';
    };
}
