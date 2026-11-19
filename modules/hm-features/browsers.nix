{ ... }:
{
  flake.homeModules.browsers =
    { ... }:
    {
      programs.brave = {
        enable = true;
        commandLineArgs = [
          "--password-store=basic"
          "--silent-debugger-extension-api"
        ];
        extensions = [
          { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; }
        ];
      };

    };
}
