{ self, ... }:
let
  mkBraveForward =
    { user, host }:
    { lib, pkgs, ... }:
    let
      name = "brave-${user}";
      toggle = pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if systemctl --user is-active --quiet ${name}.service; then
            systemctl --user stop ${name}.service
            echo "Stopped Brave forwarding from ${host}."
          else
            : "''${WAYLAND_DISPLAY:?Run ${name} from your Wayland desktop session.}"
            systemctl --user import-environment WAYLAND_DISPLAY
            if [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then
              systemctl --user import-environment SSH_AUTH_SOCK
            fi
            systemctl --user start ${name}.service
            echo "Requested Brave forwarding from ${host}."
          fi
        '';
      };
    in
    {
      home.packages = [ toggle ];
      programs.zsh.shellAliases.${name} = lib.getExe toggle;

      # No WantedBy: this session starts only through the toggle.
      systemd.user.services.${name} = {
        Unit = {
          Description = "Brave on ${host} over Waypipe";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          # Use the remote user's normal Brave profile, including its extensions.
          # Close any existing remote Brave session before starting this service:
          # otherwise Brave hands off to it and exits, breaking toggle tracking.
          # Isolate D-Bus so file dialogs cannot use the remote desktop's portal;
          # request GTK's in-process picker so its windows also use Waypipe.
          ExecStart = "${lib.getExe pkgs.waypipe} --no-gpu --ssh-bin ${pkgs.openssh}/bin/ssh ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 ${user}@${host} dbus-run-session -- env GTK_USE_PORTAL=0 brave --disable-gpu";
          TimeoutStopSec = 15;
        };
      };
    };
in
{
  flake.homeModules = {
    braveCapcu = mkBraveForward {
      user = "capcu";
      host = "capcuDell";
    };
    braveVir = mkBraveForward {
      user = "vir";
      host = "rogdesktop";
    };
  };

  flake.nixosModules.braveCapcu = {
    home-manager.users.capcu.imports = [ self.homeModules.braveCapcu ];
  };
}
