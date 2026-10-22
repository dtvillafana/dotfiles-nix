{ inputs, ... }:
{
  flake.homeModules.voxtype =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      voxtype = pkgs.voxtype.override { onnxSupport = true; };
      tray = pkgs.callPackage ../../packages/voxtype-tray.nix {
        inherit voxtype;
        inherit (inputs) voxtype-tray-src;
      };
    in
    {
      key = "dotfiles-nix-voxtype";

      home.packages = [
        voxtype
        tray
      ];

      # Keep defaults in Nix, but let the GUI own the live, writable file.
      xdg.configFile."voxtype/config.toml" = {
        enable = false;
        source = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
          engine = "parakeet";
          state_file = "auto";
          # nixpkgs' 0.7.2 does not ship an OSD frontend; use notifications.
          osd.enabled = false;
          hotkey = {
            enabled = false;
            mode = "toggle";
          };
          audio = {
            # Use the shared PipeWire PCM, never open USB hardware exclusively.
            device = "pipewire";
            sample_rate = 16000;
            max_duration_secs = 120;
          };
          parakeet = {
            # Download per user with `voxtype setup model`.
            model = "parakeet-tdt-0.6b-v3-int8";
            model_type = "tdt";
            on_demand_loading = false;
            # 0.7.2's streaming pipeline requires a different model export and
            # only commits text on stop. Keep the supported batch TDT path.
            streaming = false;
          };
          output = {
            mode = "type";
            fallback_to_clipboard = true;
            pre_type_delay_ms = 150;
            notification = {
              on_recording_start = true;
              on_recording_stop = true;
              on_transcription = false;
            };
          };
        };
      };

      home.activation.initializeVoxtypeConfig =
        lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            run ${pkgs.writeShellScript "initialize-voxtype-config" ''
              set -eu
              settings=${lib.escapeShellArg "${config.xdg.configHome}/voxtype/config.toml"}
              mkdir -p "$(dirname "$settings")"
              if [ -L "$settings" ]; then
                # Migrate the previous Home Manager symlink without losing settings.
                case "$(readlink -f "$settings")" in
                  /nix/store/*)
                    temporary=$(mktemp "$settings.XXXXXX")
                    trap 'rm -f "$temporary"' EXIT
                    install -m 0600 "$settings" "$temporary"
                    mv -T "$temporary" "$settings"
                    ;;
                esac
              elif [ ! -e "$settings" ]; then
                install -m 0600 ${config.xdg.configFile."voxtype/config.toml".source} "$settings"
              fi
            ''}
          '';

      # Hyprland owns hotkeys: evdev would require access to every keyboard.
      xdg.configFile."hypr/user.lua".text = lib.mkBefore ''
        local voxtype_held = false
        local voxtype_start = hl.dsp.exec_cmd("${lib.getExe voxtype} record start")
        local voxtype_stop = hl.dsp.exec_cmd("${lib.getExe voxtype} record stop")
        local voxtype_toggle = hl.dsp.exec_cmd("${lib.getExe voxtype} record toggle")
        local voxtype_cancel = hl.dsp.exec_cmd("${lib.getExe voxtype} record cancel")

        hl.bind("Alt_R", function()
          if voxtype_held then return end
          voxtype_held = true
          hl.dispatch(voxtype_start)
        end, { description = "Hold Right Alt to dictate", ignore_mods = true })

        hl.bind("Alt_R", function()
          if not voxtype_held then return end
          voxtype_held = false
          hl.dispatch(voxtype_stop)
        end, {
          description = "Stop Right Alt dictation",
          release = true,
          ignore_mods = true,
          submap_universal = true,
        })

        -- Only toggle after key release; do not toggle during held dictation.
        hl.bind("ALT + space", function()
          if not voxtype_held then hl.dispatch(voxtype_toggle) end
        end, {
          description = "Toggle Voxtype dictation",
          release = true,
        })
        hl.bind("ALT + Escape", function()
          voxtype_held = false
          hl.dispatch(voxtype_cancel)
        end, {
          description = "Cancel Voxtype dictation",
          release = true,
        })
      '';

      systemd.user.services.voxtype = {
        Unit = {
          Description = "Voxtype local dictation";
          After = [
            "graphical-session.target"
            "pipewire.service"
          ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          # Also override existing GUI settings that enabled evdev monitoring.
          ExecStart = "${lib.getExe voxtype} --no-hotkey daemon";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      systemd.user.services.voxtype-tray = {
        Unit = {
          Description = "Voxtype settings and tray applet";
          After = [
            "graphical-session.target"
            "voxtype.service"
          ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe tray;
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
