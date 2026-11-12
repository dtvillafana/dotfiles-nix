{ inputs, ... }:
{
  flake.homeModules.hex =
    { lib, pkgs, ... }:
    let
      # Keep native libraries on our nixpkgs while tracking a current compiler.
      rust = (pkgs.extend inputs.rust-overlay.overlays.default).rust-bin.stable.latest.default;
      hex =
        (inputs.hex.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rust;
            rustc = rust;
          };
        }).overrideAttrs
          {
            doCheck = false;
          };
    in
    {
      key = "dotfiles-nix-hex";

      imports = [ inputs.hex.homeManagerModules.hex ];

      programs.hex = {
        enable = true;
        autostart = true;
        package = hex;
      };

      # Hyprland delivers press/release events through the shortcuts portal;
      # Hex owns Hold/Toggle behavior, so changes in its GUI apply immediately.
      xdg.configFile."hypr/user.lua".text = lib.mkBefore ''
        hl.bind("ALT + Space", hl.dsp.global("anomaly.hex:dictation"), {
          description = "Hex dictation",
        })
      '';
    };
}
