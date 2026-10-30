{
  lib,
  llama-cpp,
  llama-cpp-k2-src,
  llama-cpp-k2-parser-fix,
}:
llama-cpp.overrideAttrs (old: {
  version = "0.8.0-parserfix";
  src = llama-cpp-k2-src;
  # The pinned source already initializes the backend in test-llama-archs.cpp.
  patches =
    builtins.filter (patch: !lib.hasInfix "07ccce23cf7fe3c84e13d810accff672b1d966bf" (toString patch)) (
      old.patches or [ ]
    )
    ++ [ llama-cpp-k2-parser-fix ];
  # Pin the UI dependency cache independently of the nixpkgs source version.
  npmDepsHash = "sha256-XLtEZsSFdk+2SyfXzBp8HQ2e27PQPpDCn1YjePU1/9w=";
  cmakeFlags = map (
    flag:
    if lib.hasPrefix "-DLLAMA_BUILD_NUMBER=" flag then
      "-DLLAMA_BUILD_NUMBER=11960"
    else if lib.hasPrefix "-DLLAMA_BUILD_COMMIT=" flag then
      "-DLLAMA_BUILD_COMMIT=8642541b2"
    else
      flag
  ) old.cmakeFlags;
  preConfigure = ''
    pushd tools/ui
    LLAMA_BUILD_NUMBER=11960 npm run build
    popd
  '';
})
