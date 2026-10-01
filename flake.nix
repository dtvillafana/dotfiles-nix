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
    hyprwhichkey-src = {
      url = "github:Juhan280/hyprwhichkey/6f4408e456bbd6b33f43845d797b92407037ae74";
      flake = false;
    };
    m365-tui = {
      url = "github:dtvillafana/m365-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zoho-desk-mcp-server = {
      url = "github:dtvillafana/zoho-desk-mcp-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ollama-src = {
      url = "github:ollama/ollama/v0.32.9";
      flake = false;
    };
    mixar-src = {
      url = "github:Mixar-AI/mixar-app/v4.1.4";
      flake = false;
    };
    mixar-blender-src = {
      # Match the upstream submodule pinned by Mixar v4.1.4.
      url = "github:blender/blender/fbe6228777e7d9afefcd61a413844e790ae75db7";
      flake = false;
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
            mixar = pkgs.callPackage ./packages/mixar.nix {
              inherit (inputs) mixar-src mixar-blender-src;
            };
            open-browser-use = pkgs.callPackage ./packages/open-browser-use.nix { };
            scriberr = pkgs.callPackage ./packages/scriberr.nix { };
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };
        };
    };
}
