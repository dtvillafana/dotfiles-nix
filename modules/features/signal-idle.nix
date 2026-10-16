{ ... }:
{
  flake.nixosModules.signalIdle =
    { config, pkgs, ... }:
    let
      python = pkgs.python3.withPackages (p: [ p.evdev ]);
    in
    {
      systemd.services.signal-idle = {
        description = "Close Signal after 30 minutes without user activity";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.iproute2 ];
        environment.SIGNAL_IDLE_IGNORED_DEVICES = builtins.toJSON config.services.sheepit.ignoredInputDevices;
        serviceConfig = {
          ExecStart = "${python}/bin/python ${./signal-idle/monitor.py}";
          Restart = "on-failure";
          RestartSec = 10;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    };
}
