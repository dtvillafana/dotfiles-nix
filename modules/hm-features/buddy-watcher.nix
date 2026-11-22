{ self, ... }:
{
  flake.nixosModules.buddyWatcher =
    {
      lib,
      secretsEnabled ? true,
      ...
    }:
    {
      imports = [ self.nixosModules.systemSecrets ];
      config = lib.mkIf secretsEnabled {
        sops.secrets = lib.genAttrs [ "buddy-worker-token" "buddy-webhook-secret" ] (key: {
          inherit key;
          sopsFile = ../../secrets/buddy-watcher.json;
          format = "json";
          owner = "vir";
          mode = "0600";
          restartUnits = [ "home-manager-vir.service" ];
        });
        home-manager.users.vir.imports = [ self.homeModules.buddyWatcher ];
      };
    };

  flake.homeModules.buddyWatcher =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (config.xdg) dataHome;
      repo = "dtvillafana/i-got-a-buddy-web";
      hook = "715126227";
      watcher = "github-i-got-a-buddy-web";
      port = "18461";
      watcherDir = "${dataHome}/agent-deck/watcher";
      webhookSecret = osConfig.sops.secrets.buddy-webhook-secret.path;
      workerToken = osConfig.sops.secrets.buddy-worker-token.path;
      profileBin = "/etc/profiles/per-user/${config.home.username}/bin";
      mkCommand =
        name: runtimeInputs: text:
        lib.getExe (
          pkgs.writeShellApplication {
            inherit name runtimeInputs;
            text = ''
              export PATH="${profileBin}:$PATH"
              ${text}
            '';
          }
        );
      engine = mkCommand "buddy-watcher-engine" [ ] ''
        ${lib.getExe pkgs.python3} ${./buddy-watcher/setup.py} \
          ${lib.escapeShellArgs [
            watcherDir
            watcher
            port
            webhookSecret
          ]}
        exec agent-deck -p default web --no-tui --read-only --listen 127.0.0.1:18462
      '';
      tunnel =
        mkCommand "buddy-watcher-tunnel"
          [
            pkgs.cloudflared
            pkgs.coreutils
            pkgs.curl
            pkgs.gh
            pkgs.gnugrep
            pkgs.jq
          ]
          ''
            export BUDDY_HOOK=${lib.escapeShellArg "repos/${repo}/hooks/${hook}"}
            export BUDDY_WEBHOOK_SECRET=${lib.escapeShellArg webhookSecret}
            export BUDDY_PORT=${port}
            ${builtins.readFile ./buddy-watcher/tunnel.sh}
          '';
      dispatcher =
        mkCommand "buddy-issues"
          [
            pkgs.git
            pkgs.gh
          ]
          ''
            export BUDDY_HOOK=${lib.escapeShellArg "repos/${repo}/hooks/${hook}"}
            export BUDDY_WORKER_TOKEN=${lib.escapeShellArg workerToken}
            export BUDDY_DISPATCHER=${lib.escapeShellArg "${config.home.homeDirectory}/.local/libexec/agent-deck/buddy-issues.py"}
            exec ${lib.getExe pkgs.python3} ${./buddy-watcher/dispatch.py} "$@"
          '';
    in
    {
      home.file.".local/libexec/agent-deck/buddy-issues.py".source = dispatcher;
      xdg.dataFile."agent-deck/conductor/master/POLICY.md".source = ./buddy-watcher/POLICY.md;

      systemd.user.services = {
        agent-deck-watcher-engine = {
          Unit.Description = "Agent Deck watcher engine (default profile)";
          Service = {
            ExecStart = engine;
            Restart = "always";
            RestartSec = "10s";
          };
          Install.WantedBy = [ "default.target" ];
        };
        github-watcher-tunnel = {
          Unit = {
            Description = "Cloudflare Quick Tunnel for the Buddy GitHub watcher";
            Wants = [ "agent-deck-watcher-engine.service" ];
            After = [ "agent-deck-watcher-engine.service" ];
          };
          Service = {
            ExecStart = tunnel;
            Restart = "always";
            RestartSec = "20s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
