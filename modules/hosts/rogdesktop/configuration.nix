{ self, inputs, ... }:
{
  flake.nixosModules.rogdesktopConfig =
    {
      config,
      hermes-agent,
      lib,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    let
      inputplumber = pkgs.inputplumber.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (pkgs.writeText "inputplumber-axis-direction.patch" ''
            diff --git a/src/input/event/evdev/translator.rs b/src/input/event/evdev/translator.rs
            index f52a018..46e553f 100644
            --- a/src/input/event/evdev/translator.rs
            +++ b/src/input/event/evdev/translator.rs
            @@ -236 +236,5 @@ impl EventTranslator {
            -            if let Some(direction) = evdev_config.axis_direction.as_ref() {
            +            if let Some(direction) = evdev_config
            +                .axis_direction
            +                .as_ref()
            +                .filter(|_| event.event_type() == evdev::EventType::ABSOLUTE)
            +            {
            @@ -254 +258,12 @@ impl EventTranslator {
            -            let value = self.get_input_value(event, &evdev_config.value_type);
            +            let mut value = self.get_input_value(event, &evdev_config.value_type);
            +            if event.event_type() == evdev::EventType::KEY
            +                && matches!(evdev_config.axis_direction, Some(AxisDirection::Negative))
            +            {
            +                value = match value {
            +                    InputValue::Vector2 { x, y } => InputValue::Vector2 {
            +                        x: x.map(|value| -value),
            +                        y: y.map(|value| -value),
            +                    },
            +                    value => value,
            +                };
            +            }
            @@ -507 +522,7 @@ impl EventTranslator {
            -            ValueType::Button => normalize_unsigned_value(raw_value, info.minimum(), info.maximum()),
            +            ValueType::Button => {
            +                if info.minimum() < 0 {
            +                    normalize_signed_value(raw_value, info.minimum(), info.maximum())
            +                } else {
            +                    normalize_unsigned_value(raw_value, info.minimum(), info.maximum())
            +                }
            +            }
          '')
        ];
      });
      retrolinkInputPlumberData = pkgs.symlinkJoin {
        name = "retrolink-inputplumber-data";
        paths = [
          inputplumber
          (pkgs.writeTextDir "share/inputplumber/devices/60-retrolink.yaml" ''
            version: 1
            kind: CompositeDevice
            name: RetroLink USB Gamepad
            options:
              auto_manage: true
            matches: []
            maximum_sources: 1
            source_devices:
              - group: gamepad
                udev:
                  attributes:
                    - name: id/vendor
                      value: "0079"
                    - name: id/product
                      value: "0006"
                  sys_name: "event*"
                  subsystem: input
                capability_map_id: retrolink
            target_devices:
              - xb360
          '')
          (pkgs.writeTextDir "share/inputplumber/capability_maps/retrolink.yaml" ''
            version: 2
            kind: CapabilityMap
            name: RetroLink USB Gamepad
            id: retrolink
            mapping:
              - name: South Button
                source_events:
                  - evdev: { event_type: KEY, event_code: BTN_BASE, value_type: button }
                target_event:
                  gamepad: { button: South }
              - name: East Button
                source_events:
                  - evdev: { event_type: KEY, event_code: BTN_BASE3, value_type: button }
                target_event:
                  gamepad: { button: East }
              - name: Start Button
                source_events:
                  - evdev: { event_type: KEY, event_code: BTN_BASE4, value_type: button }
                target_event:
                  gamepad: { button: Start }
              - name: Left Bumper
                source_events:
                  - evdev: { event_type: KEY, event_code: BTN_TOP2, value_type: button }
                target_event:
                  gamepad: { button: LeftBumper }
              - name: Right Trigger
                source_events:
                  - evdev: { event_type: KEY, event_code: BTN_PINKIE, value_type: trigger }
                target_event:
                  gamepad:
                    trigger: { name: RightTrigger }
              - name: Left Trigger
                source_events:
                  - evdev: { event_type: KEY, event_code: BTN_BASE2, value_type: trigger }
                target_event:
                  gamepad:
                    trigger: { name: LeftTrigger }
              - name: Ignore Noisy Z Axis
                source_events:
                  - evdev: { event_type: ABS, event_code: ABS_Z, value_type: trigger }
                target_event: {}
              - name: Left Stick
                source_events:
                  - evdev: { event_type: ABS, event_code: ABS_X, value_type: joystick_x }
                  - evdev: { event_type: ABS, event_code: ABS_Y, value_type: joystick_y }
                target_event:
                  gamepad:
                    axis: { name: LeftStick }
              - name: Right Stick
                mapping_type:
                  evdev: multi_source
                source_events:
                  - evdev: { event_type: KEY, event_code: BTN_TOP, value_type: joystick_x, axis_direction: negative }
                  - evdev: { event_type: KEY, event_code: BTN_THUMB, value_type: joystick_x, axis_direction: positive }
                  - evdev: { event_type: KEY, event_code: BTN_TRIGGER, value_type: joystick_y, axis_direction: negative }
                  - evdev: { event_type: KEY, event_code: BTN_THUMB2, value_type: joystick_y, axis_direction: positive }
                target_event:
                  gamepad:
                    axis: { name: RightStick }
              - name: D-pad Left
                source_events:
                  - evdev: { event_type: ABS, event_code: ABS_HAT0X, value_type: button, axis_direction: negative }
                target_event:
                  gamepad: { button: DPadLeft }
              - name: D-pad Right
                source_events:
                  - evdev: { event_type: ABS, event_code: ABS_HAT0X, value_type: button, axis_direction: positive }
                target_event:
                  gamepad: { button: DPadRight }
              - name: D-pad Up
                source_events:
                  - evdev: { event_type: ABS, event_code: ABS_HAT0Y, value_type: button, axis_direction: negative }
                target_event:
                  gamepad: { button: DPadUp }
              - name: D-pad Down
                source_events:
                  - evdev: { event_type: ABS, event_code: ABS_HAT0Y, value_type: button, axis_direction: positive }
                target_event:
                  gamepad: { button: DPadDown }
          '')
        ];
      };
      xsessionInitExtra = ''
        xset -dpms
        xset s off
        xset s noblank
      '';
    in
    {
      imports = [
        self.nixosModules.androidTools
        self.nixosModules.rogdesktopHardware
      ];

      services.xserver.videoDrivers = [ "nvidia" ];

      nixpkgs.config.cudaCapabilities = [ "6.1" ];

      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        modesetting.enable = true;
        open = false;
      };

      hardware.graphics.enable = true;

      programs.steam.enable = true;

      services.inputplumber = {
        enable = true;
        package = inputplumber;
      };
      systemd.services.inputplumber.environment.XDG_DATA_DIRS =
        lib.mkForce "${retrolinkInputPlumberData}/share";

      services.ollama.loadModels = lib.mkForce [ "qwen3.5:9b" ];

      sops.secrets."hermes-env" = lib.mkIf secretsEnabled {
        restartUnits = [
          "hermes-agent.service"
          "hermes-webui.service"
        ];
      };

      services.hermes-agent = lib.mkIf secretsEnabled {
        enable = true;
        package = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
        container.enable = false;
        addToSystemPackages = true;
        user = "vir";
        group = "vir";
        createUser = false;
        workingDirectory = "/home/vir/git-repos";
        extraPackages = config.home-manager.users.vir.home.packages;
        environmentFiles = [ config.sops.secrets."hermes-env".path ];
        environment = {
          API_SERVER_HOST = "127.0.0.1";
          API_SERVER_PORT = "8642";
        };
        settings = {
          toolsets = [ "all" ];
          platforms.api_server.enabled = true;
          model = {
            provider = "custom";
            base_url = "http://127.0.0.1:11434/v1";
            default = "qwen3.5:9b";
            context_length = 65536;
          };
          max_turns = 100;
          agent = {
            max_turns = 60;
            verbose = true;
            tool_use_enforcement = true;
            intent_ack_continuation = true;
          };
          memory = {
            memory_enabled = true;
            user_profile_enabled = true;
          };
          terminal = {
            cwd = "/home/vir/git-repos";
            backend = "local";
            timeout = 180;
          };
        };
      };

      services.hermes-webui = lib.mkIf secretsEnabled {
        enable = true;
        user = "vir";
        group = "vir";
        stateDir = "/home/vir/.hermes/webui";
        hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
        agent.package = config.services.hermes-agent.package;
        environmentFiles = [ config.sops.secrets."hermes-env".path ];
        extraEnvironment.HERMES_WEBUI_CHAT_BACKEND = "legacy";
      };

      systemd.services.hermes-agent = lib.mkIf secretsEnabled {
        after = [ "ollama-model-loader.service" ];
        requires = [ "ollama-model-loader.service" ];
        environment.HOME = lib.mkForce "/home/vir";
        restartTriggers = [
          (pkgs.writeText "hermes-agent-gateway-config" (
            builtins.toJSON {
              inherit (config.services.hermes-agent) environment settings;
            }
          ))
        ];
        serviceConfig.TimeoutStopSec = 210;
      };

      systemd.services.hermes-webui = lib.mkIf secretsEnabled {
        after = [ "hermes-agent.service" ];
        requires = [ "hermes-agent.service" ];
      };

      home-manager.users = builtins.listToAttrs (
        map
          (username: {
            name = username;
            value.xsession.initExtra = xsessionInitExtra;
          })
          [
            "vir"
            "capcu"
          ]
      );
    };
}
