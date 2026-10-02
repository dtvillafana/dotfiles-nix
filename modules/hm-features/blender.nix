{ self, inputs, ... }:
{
  flake.nixosModules.blender = {
    home-manager.users.vir.imports = [ self.homeModules.blender ];
  };

  flake.homeModules.blender =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      home.packages = [
        pkgs.blender
        self.packages.${system}.mcp-for-blender
        self.packages.${system}.mixar
      ];

      opencode.settings.mcp.servers.blender = {
        type = "local";
        command = [ "${self.packages.${system}.mcp-for-blender}/bin/mcp-for-blender" ];
        environment = {
          BLENDER_HOST = "localhost";
          BLENDER_PORT = "9876";
          DISABLE_TELEMETRY = "true";
        };
      };

      home.file.".config/blender/${lib.versions.majorMinor pkgs.blender.version}/scripts/addons/blender_mcp.py".source =
        inputs.mcp-for-blender-src + /addon.py;
    };
}
