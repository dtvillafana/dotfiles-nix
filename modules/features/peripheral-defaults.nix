{ ... }:
let
  openRun = {
    "device.name" = "bluez_card.A0_0C_E2_A0_81_E2";
  };
in
{
  flake.nixosModules.peripheralDefaults = {
    key = "dotfiles-nix-peripheral-defaults";

    services.pipewire.wireplumber.extraConfig."60-openrun-shokz" = {
      "monitor.bluez.rules" = [
        {
          matches = [ openRun ];
          # Connect A2DP even if the headset initially connects only hands-free.
          actions.update-props."bluez5.auto-connect" = [ "a2dp_sink" ];
        }
      ];

      "device.profile.priority.rules" = [
        {
          matches = [ openRun ];
          actions.update-props.priorities = [
            "a2dp-sink-sbc_xq"
            "a2dp-sink"
          ];
        }
      ];
    };
  };
}
