{ inputs, ... }:
{
  flake.homeModules.agent-deck =
    { llm-agents, system, ... }:
    {
      home.packages = [
        (
          (llm-agents.packages.${system}.agent-deck.override {
            # The fork requires Go >= 1.26.9; the default toolchain is still 1.26.8.
            buildGoModule = llm-agents.inputs.nixpkgs.legacyPackages.${system}.buildGo127Module;
          }).overrideAttrs
            (old: rec {
              version = "${old.version}-fork";
              src = inputs.agent-deck-src;
              vendorHash = "sha256-v3vhZiTTktjmWuv4FTWAEiHaeSUXyVRVTOL02UeZZrw=";
              doCheck = false;
              ldflags = builtins.map (builtins.replaceStrings [ old.version ] [ version ]) old.ldflags;
            })
        )
      ];

      home.file.".config/agent-deck/config.toml".text = ''
        default_tool = "claude"
        theme = "dark"

        [tools.terminal]
        command = "zsh"
        icon = "⌨"

        [claude]
        dangerous_mode = false

        [global_search]
        enabled = true
        tier = "auto"
        recent_days = 90

        [recall]
        enabled = true

        [instances]
        allow_multiple = true
      '';
    };
}
