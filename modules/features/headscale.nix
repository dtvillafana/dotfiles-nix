{ self, ... }:
{
  flake.nixosModules.headscale =
    {
      config,
      lib,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    let
      headscaleGitDns = pkgs.writeShellApplication {
        name = "headscale-git-dns";
        runtimeInputs = [
          pkgs.jq
          pkgs.systemd
          pkgs.tailscale
        ];
        text = ''
          if ! tailscale status --json --peers=false | jq -e '.BackendState == "Running"' >/dev/null; then
            echo "Headscale is not connected yet." >&2
            exit 1
          fi

          exit_node_enabled="$(tailscale debug prefs | jq -r '(.ExitNodeID // "") != "" or (.ExitNodeIP // "") != ""')"
          if [ "$exit_node_enabled" = false ]; then
            magic_dns_suffix="$(tailscale status --json --peers=false | jq -r '.MagicDNSSuffix // empty')"
            if [ -z "$magic_dns_suffix" ]; then
              echo "Headscale MagicDNS suffix is not available yet." >&2
              exit 1
            fi

            # A search domain resolves short hostnames and routes tailnet DNS only.
            resolvectl domain tailscale0 "$magic_dns_suffix" '~git.dvilla.me'
            resolvectl default-route tailscale0 false
            resolvectl dns tailscale0 100.100.100.100
          fi
        '';
      };
    in
    {
      imports = [ self.nixosModules.systemSecrets ];
      services.resolved.enable = true;
      sops.secrets.headscale_preauth_key = lib.mkIf secretsEnabled {
        mode = "0400";
      };
      services.tailscale = {
        enable = true;
        openFirewall = true;
        useRoutingFeatures = "client";
      }
      // lib.optionalAttrs secretsEnabled {
        authKeyFile = config.sops.secrets.headscale_preauth_key.path;
        extraUpFlags = [
          "--login-server=https://ts.dvilla.me"
          "--hostname=${config.networking.hostName}"
          "--exit-node="
          "--accept-dns=false"
        ];
        extraSetFlags = [
          "--hostname=${config.networking.hostName}"
          "--exit-node="
          "--accept-dns=false"
        ];
      };

      systemd.services.tailscaled-autoconnect =
        lib.mkIf (secretsEnabled && config.services.tailscale.enable)
          {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            unitConfig.StartLimitIntervalSec = 0;
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "10s";
            };
          };
      systemd.services.tailscaled-set = lib.mkIf (secretsEnabled && config.services.tailscale.enable) {
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "10s";
        };
      };
      systemd.services.headscale-git-dns = lib.mkIf (secretsEnabled && config.services.tailscale.enable) {
        description = "Route MagicDNS and Git DNS through Headscale when the exit node is off";
        wantedBy = [
          "multi-user.target"
          "systemd-resolved.service"
          "tailscaled.service"
        ];
        after = [
          "systemd-resolved.service"
          "tailscaled.service"
          "tailscaled-autoconnect.service"
          "tailscaled-set.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        script = lib.getExe headscaleGitDns;
      };

      environment.systemPackages = [
        pkgs.tailscale
        (pkgs.writeShellApplication {
          name = "headscale-toggle";
          runtimeInputs = [
            pkgs.jq
            pkgs.tailscale
          ];
          text = ''
            if [ "$#" -ne 0 ]; then
              echo "Usage: headscale-toggle" >&2
              exit 1
            fi

            if ! tailscale status --json --peers=false | jq -e '.BackendState == "Running"' >/dev/null; then
              echo "Headscale is not connected; check tailscaled-autoconnect.service." >&2
              exit 1
            fi

            # Preferences describe the selected exit node even when it is offline
            # or the runtime status has not caught up yet.
            exit_node_enabled="$(tailscale debug prefs | jq -r '(.ExitNodeID // "") != "" or (.ExitNodeIP // "") != ""')"
            if [ "$exit_node_enabled" = true ]; then
              /run/wrappers/bin/sudo ${lib.getExe pkgs.tailscale} set --exit-node= --accept-dns=false
              /run/wrappers/bin/sudo ${lib.getExe headscaleGitDns}
              echo "Headscale exit node and general DNS disabled; hostnames and Git remain on Headscale."
            else
              /run/wrappers/bin/sudo ${lib.getExe pkgs.tailscale} set --exit-node=nixos-headscale-linode --accept-dns=true
              echo "Headscale exit node and DNS enabled."
            fi
          '';
        })
      ];
    };
}
