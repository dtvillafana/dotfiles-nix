{
  lib,
  python313Packages,
  mcp-for-blender-src,
}:

python313Packages.buildPythonApplication {
  pname = "mcp-for-blender";
  version = "2.1.3";
  pyproject = true;
  src = mcp-for-blender-src;

  build-system = with python313Packages; [ setuptools ];
  dependencies = with python313Packages; [
    httpx
    mcp
  ];

  # The upstream wheel bundles the add-on for version checks and installation.
  preBuild = ''
    mkdir -p src/blender_mcp/bundled
    cp addon.py src/blender_mcp/bundled/addon.py
  '';

  pythonImportsCheck = [ "blender_mcp.server" ];

  meta = {
    description = "Control Blender through the Model Context Protocol";
    homepage = "https://github.com/ahujasid/mcp-for-blender";
    license = lib.licenses.mit;
    mainProgram = "mcp-for-blender";
    platforms = lib.platforms.linux;
  };
}
