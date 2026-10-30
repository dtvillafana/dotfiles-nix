{
  description = "NixOS configurations for David";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605.0";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";
    hermes-webui = {
      url = "github:nesquena/hermes-webui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    llama-cpp-k2-src = {
      # Latest stable v0.8.0; retain CUDA 12 for Pascal in the host profile.
      url = "github:ggml-org/llama.cpp/8642541b255bfb5dc39cd351a178be09013a55d6";
      flake = false;
    };
    llama-cpp-k2-parser-fix = {
      # Unmerged upstream PR #30335: accept the generic closer at medium/low effort.
      type = "file";
      url = "https://github.com/ggml-org/llama.cpp/commit/406bd24fe19818796bbf4ceed4828ad2482f934a.patch";
      flake = false;
    };
    k2-horizon-7b-chat-template = {
      # The GGUF's minimal replacement template drops tool definitions.
      type = "file";
      url = "https://huggingface.co/Avicennasis/K2-Horizon-7B-heretic/resolve/b364bdb85dca419c662cfa82bcdca75b592036b6/chat_template.jinja";
      flake = false;
    };
    agent-deck-src = {
      url = "github:dtvillafana/agent-deck/main";
      flake = false;
    };
    fast-browser-mcp-src = {
      url = "github:kqlio67/fast-browser-mcp/v0.10.0";
      flake = false;
    };
    octoprint-malyan-connection-fix-src = {
      url = "github:OctoPrint/OctoPrint-MalyanConnectionFix/5a935585a396c129f061e8c43227707562079e05";
      flake = false;
    };
    octoprint-src = {
      url = "github:OctoPrint/OctoPrint/1.11.8";
      flake = false;
    };
    octoprint-filecheck-src = {
      url = "github:OctoPrint/OctoPrint-FileCheck/2025.7.23";
      flake = false;
    };
    octoprint-firmwarecheck-src = {
      url = "github:OctoPrint/OctoPrint-FirmwareCheck/2025.7.23";
      flake = false;
    };
    voxtype-tray-src = {
      url = "github:matt-shearing/voxtype-tray/6fcacd82fc52299c3b152962ff3737a16cc42b68";
      flake = false;
    };
    hyprwhichkey-src = {
      url = "github:Juhan280/hyprwhichkey/6f4408e456bbd6b33f43845d797b92407037ae74";
      flake = false;
    };
    hyprmon-src = {
      # Backport Lua monitor support to the packaged release.
      url = "github:erans/hyprmon/43f06d7e6d144df2d200914fdc695d74f11ed721";
      flake = false;
    };
    hokum.url = "github:anomalyco/hokum";
    m365-tui = {
      url = "github:dtvillafana/m365-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zoho-desk-mcp-server = {
      url = "github:dtvillafana/zoho-desk-mcp-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-for-blender-src = {
      url = "github:ahujasid/mcp-for-blender/60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4";
      flake = false;
    };
    nixvim = {
      url = "github:dtvillafana/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.llm-agents.follows = "llm-agents";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.home-manager.flakeModules.home-manager
        (inputs.import-tree ./modules)
      ];

      perSystem =
        {
          lib,
          pkgs,
          system,
          ...
        }:
        {
          packages = lib.optionalAttrs (system == "x86_64-linux") {
            excise = pkgs.callPackage ./packages/excise.nix { };
            mcp-for-blender = pkgs.callPackage ./packages/mcp-for-blender.nix {
              inherit (inputs) mcp-for-blender-src;
            };
            open-browser-use = pkgs.callPackage ./packages/open-browser-use.nix { };
            scriberr = pkgs.callPackage ./packages/scriberr.nix { };
            sheepit-client = pkgs.callPackage ./packages/sheepit-client.nix { };
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };
        };
    };
}
