{
  lib,
  buildPythonPackage,
  setuptools,
  octoprint,
  octoprint-malyan-connection-fix-src,
}:
buildPythonPackage {
  pname = "octoprint-malyan-connection-fix";
  version = "0.1.3";
  pyproject = true;
  src = octoprint-malyan-connection-fix-src;

  build-system = [
    setuptools
    octoprint
  ];
  dependencies = [ octoprint ];
  pythonImportsCheck = [ "octoprint_malyan_connection_fix" ];

  meta = {
    description = "Serial connection workaround for Malyan and Monoprice 3D printers";
    homepage = "https://github.com/OctoPrint/OctoPrint-MalyanConnectionFix";
    license = lib.licenses.agpl3Only;
  };
}
