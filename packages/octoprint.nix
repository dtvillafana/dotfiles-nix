{
  octoprint,
  octoprint-src,
  octoprint-filecheck-src,
  octoprint-firmwarecheck-src,
}:
octoprint.override {
  packageOverrides = _: prev: {
    octoprint = prev.octoprint.overridePythonAttrs (old: {
      version = "1.11.8";
      src = octoprint-src;
      # These integration tests require an independently running, configured server.
      disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [ "tests/http_api" ];
    });
    octoprint-filecheck = prev.octoprint-filecheck.overridePythonAttrs {
      version = "2025.7.23";
      src = octoprint-filecheck-src;
    };
    octoprint-firmwarecheck = prev.octoprint-firmwarecheck.overridePythonAttrs {
      version = "2025.7.23";
      src = octoprint-firmwarecheck-src;
    };
  };
}
