{
  lib,
  python313Packages,
  fast-browser-mcp-src,
}:

python313Packages.buildPythonApplication {
  pname = "fast-browser-mcp";
  version = "0.10.0";
  pyproject = true;
  src = fast-browser-mcp-src;

  build-system = with python313Packages; [ setuptools ];
  dependencies = with python313Packages; [
    aiofiles
    requests
    websockets
  ];

  pythonImportsCheck = [ "fast_browser.server" ];

  meta = {
    description = "Local CDP browser automation MCP server with batched actions";
    homepage = "https://github.com/kqlio67/fast-browser-mcp";
    license = lib.licenses.mit;
    mainProgram = "fast-browser-mcp";
    platforms = lib.platforms.linux;
  };
}
