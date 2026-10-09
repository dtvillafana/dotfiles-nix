{ ... }:
{
  flake.nixosModules.lowBatteryDim =
    { lib, pkgs, ... }:
    let
      lowBatteryDim = pkgs.writeShellApplication {
        name = "low-battery-dim";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          shopt -s nullglob
          low_battery=false
          for battery in /sys/class/power_supply/*; do
            [ -r "$battery/type" ] && [ -r "$battery/status" ] && [ -r "$battery/capacity" ] || continue
            read -r type < "$battery/type"
            [ "$type" = Battery ] || continue
            # Ignore peripheral batteries, such as mice and headsets.
            if [ -r "$battery/scope" ]; then
              read -r scope < "$battery/scope"
              [ "$scope" != Device ] || continue
            fi
            read -r status < "$battery/status"
            read -r capacity < "$battery/capacity"
            if [ "$status" = Discharging ] && (( capacity < 10 )); then
              low_battery=true
              break
            fi
          done

          state="$RUNTIME_DIRECTORY/dimmed"
          if [ "$low_battery" = false ]; then
            rm -f "$state"
            exit 0
          fi
          # Dim once per low-battery episode, allowing manual changes afterward.
          [ ! -e "$state" ] || exit 0
          for backlight in /sys/class/backlight/*; do
            read -r brightness < "$backlight/brightness"
            # Raw level 1 is the first step above off; never turn an off screen on.
            if (( brightness > 1 )); then
              printf '1\n' > "$backlight/brightness"
            fi
          done
          touch "$state"
        '';
      };
    in
    {
      systemd.services.low-battery-dim = {
        description = "Dim displays to the lowest nonzero brightness below 10% battery";
        unitConfig.ConditionPathExistsGlob = "/sys/class/backlight/*";
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "low-battery-dim";
          RuntimeDirectoryPreserve = "yes";
          ExecStart = lib.getExe lowBatteryDim;
        };
      };
      systemd.timers.low-battery-dim = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "30s";
          AccuracySec = "1s";
        };
      };
    };
}
