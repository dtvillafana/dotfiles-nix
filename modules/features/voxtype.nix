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
      hotkeyMode = pkgs.writeScript "voxtype-hotkey-mode" ''
        #!${pkgs.python3}/bin/python3
        import sys
        import tomllib
        from pathlib import Path

        path = Path(${builtins.toJSON "${config.xdg.configHome}/voxtype/config.toml"})
        try:
            settings = tomllib.loads(path.read_text())
        except FileNotFoundError:
            settings = {}
        except (OSError, tomllib.TOMLDecodeError) as error:
            print(f"Cannot read Voxtype hotkey mode: {error}", file=sys.stderr)
            sys.exit(1)

        mode = settings.get("hotkey", {}).get("mode", "push_to_talk")
        # Match the daemon's in-memory streaming override, even if the GUI
        # leaves hotkey.mode set to push_to_talk in the file.
        if settings.get("parakeet", {}).get("streaming", False):
            mode = "toggle"
        if mode not in ("toggle", "push_to_talk"):
            sys.exit("Unknown Voxtype hotkey mode")
        print(mode)
      '';
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
            # Streaming requires a different model export, such as
            # parakeet-unified-en-0.6b. Default to the batch TDT path.
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
        local voxtype_key = nil
        local voxtype_mode = nil
        local voxtype_start = hl.dsp.exec_cmd("${lib.getExe voxtype} record start")
        local voxtype_stop = hl.dsp.exec_cmd("${lib.getExe voxtype} record stop")
        local voxtype_toggle = hl.dsp.exec_cmd("${lib.getExe voxtype} record toggle")
        local voxtype_cancel = hl.dsp.exec_cmd("${lib.getExe voxtype} record cancel")

        local function voxtype_bind(key, ignore_mods)
          hl.bind(key, function()
            -- Suppress repeats and overlapping dictation shortcuts.
            if voxtype_key then return end
            local reader = io.popen("${hotkeyMode}", "r")
            if not reader then return end
            local mode = reader:read("*l")
            local ok = reader:close()
            if not ok or (mode ~= "toggle" and mode ~= "push_to_talk") then return end
            voxtype_key = key
            voxtype_mode = mode
            if mode == "push_to_talk" then hl.dispatch(voxtype_start) end
          end, { description = "Voxtype: configured toggle/hold mode", ignore_mods = ignore_mods })

          hl.bind(key, function()
            if voxtype_key ~= key then return end
            -- Retain the press-time mode even if settings change while held.
            local mode = voxtype_mode
            voxtype_key = nil
            voxtype_mode = nil
            if mode == "toggle" then
              hl.dispatch(voxtype_toggle)
            elseif mode == "push_to_talk" then
              hl.dispatch(voxtype_stop)
            end
          end, {
            description = "Voxtype: release toggle/hold key",
            release = true,
            ignore_mods = ignore_mods,
            submap_universal = true,
          })
        end

        -- Toggle only on release so typing never starts with the key held.
        voxtype_bind("Alt_R", true)
        voxtype_bind("ALT + space", false)
        hl.bind("ALT + Escape", function()
          -- Keep the key latched until release; cancelling must not re-toggle.
          voxtype_mode = "cancelled"
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
