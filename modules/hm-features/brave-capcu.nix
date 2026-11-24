{ self, ... }:
{
  flake.homeModules.braveCapcu =
    { lib, pkgs, ... }:
    let
      toggle = pkgs.writeShellApplication {
        name = "brave-capcu";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if systemctl --user is-active --quiet brave-capcu.service; then
            systemctl --user stop brave-capcu.service
            echo "Stopped Brave forwarding from capcuDell."
          else
            : "''${WAYLAND_DISPLAY:?Run brave-capcu from your Wayland desktop session.}"
            systemctl --user import-environment WAYLAND_DISPLAY
            if [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then
              systemctl --user import-environment SSH_AUTH_SOCK
            fi
            systemctl --user start brave-capcu.service
            echo "Started Brave forwarding from capcuDell."
          fi
        '';
      };
    in
    {
      home.packages = [ toggle ];
      programs.zsh.shellAliases.brave-capcu = lib.getExe toggle;

      # No WantedBy: this session starts only through the toggle.
      systemd.user.services.brave-capcu = {
        Unit = {
          Description = "Brave on capcuDell over Waypipe";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          # Use capcu's normal Brave profile, including its extensions. Close any
          # existing Brave session on the Dell before starting this service:
          # otherwise Brave hands off to it and exits, breaking toggle tracking.
          # Isolate D-Bus so file dialogs cannot use the Dell's existing portal;
          # request GTK's in-process picker so its windows also use Waypipe.
          ExecStart = "${lib.getExe pkgs.waypipe} --no-gpu --ssh-bin ${pkgs.openssh}/bin/ssh ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 capcu@capcuDell dbus-run-session -- env GTK_USE_PORTAL=0 brave --disable-gpu";
          TimeoutStopSec = 15;
        };
      };
    };

  flake.nixosModules.braveCapcu = {
    home-manager.users.capcu.imports = [ self.homeModules.braveCapcu ];
  };
}
