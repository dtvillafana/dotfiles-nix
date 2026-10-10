{ self, ... }:
{
  flake.nixosModules.sheepit =
    {
      config,
      lib,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    let
      cfg = config.services.sheepit;
      python = pkgs.python3.withPackages (p: [ p.evdev ]);
      credentialsFile = config.sops.secrets.sheepit-config.path;
    in
    {
      options.services.sheepit = {
        enable = lib.mkEnableOption "idle-only SheepIt CPU and GPU rendering";
        idleSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 900;
        };
        memoryGiB = lib.mkOption {
          type = lib.types.ints.positive;
          default = 8;
        };
        sopsFile = lib.mkOption {
          type = lib.types.path;
          default = self + /secrets/sheepit.yaml;
          description = "Encrypted YAML file with a sheepit-config key containing login and password (render key) as Java properties.";
        };
      };
      config = lib.mkIf (cfg.enable && secretsEnabled) {
        users.groups.sheepit = { };
        users.users.sheepit = {
          isSystemUser = true;
          group = "sheepit";
          extraGroups = [
            "video"
            "render"
          ];
          home = "/var/lib/sheepit";
        };
        sops.secrets.sheepit-config = {
          sopsFile = cfg.sopsFile;
          format = "yaml";
          # Re-enter the idle gate instead of starting a worker on key rotation.
          restartUnits = [ "sheepit-idle.service" ];
        };
        systemd.tmpfiles.rules = [ "d /var/lib/sheepit 0700 sheepit sheepit -" ];
        systemd.services.sheepit = {
          description = "SheepIt legacy CPU/GPU worker (managed by sheepit-idle)";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          unitConfig.ConditionPathExists = credentialsFile;
          serviceConfig = {
            User = "sheepit";
            Group = "sheepit";
            StateDirectory = "sheepit";
            WorkingDirectory = "/var/lib/sheepit";
            LoadCredential = "client.conf:${credentialsFile}";
            ExecStart = "${
              lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.sheepit-client
            } -config %d/client.conf -ui oneLine --headless --no-systray -compute-method CPU_GPU -gpu OPTIX_0 -cores 2 -memory ${toString cfg.memoryGiB}G -priority 19 -hostname ${config.networking.hostName} -cache-dir /var/lib/sheepit/cache";
            Environment = "HOME=/var/lib/sheepit";
            Nice = 19;
            CPUWeight = 1;
            IOWeight = 1;
            MemoryHigh = "${toString cfg.memoryGiB}G";
            MemoryMax = "${toString (cfg.memoryGiB + 2)}G";
            UMask = "0077";
            KillMode = "control-group";
            TimeoutStopSec = 3;
            Restart = "on-failure";
            RestartSec = 60;
            # buildFHSEnv needs user namespaces; don't enable NoNewPrivileges here.
          };
        };
        systemd.services.sheepit-idle = {
          description = "SheepIt local-input and GPU contention monitor";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-logind.service" ];
          path = [
            pkgs.systemd
            config.hardware.nvidia.package
          ];
          environment = {
            SHEEPIT_IDLE_SECONDS = toString cfg.idleSeconds;
            SHEEPIT_CREDENTIALS = credentialsFile;
          };
          serviceConfig = {
            ExecStart = "${python}/bin/python ${./sheepit/idle.py}";
            ExecStopPost = "${pkgs.systemd}/bin/systemctl stop sheepit.service";
            Restart = "on-failure";
            RestartSec = 10;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          };
        };
      };
    };
}
