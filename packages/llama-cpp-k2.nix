{
  lib,
  llama-cpp,
  llama-cpp-k2-src,
  llama-cpp-k2-parser-fix,
}:
llama-cpp.overrideAttrs (old: {
  version = "0.6.0-k2-cache-d6cf9ac-parserfix";
  src = llama-cpp-k2-src;
  # The pinned source already initializes the backend in test-llama-archs.cpp.
  patches =
    builtins.filter (patch: !lib.hasInfix "07ccce23cf7fe3c84e13d810accff672b1d966bf" (toString patch)) (
      old.patches or [ ]
    )
    ++ [ llama-cpp-k2-parser-fix ];
  # tools/ui/package-lock.json is unchanged from v0.6.0, so retain npmDepsHash.
  cmakeFlags = map (
    flag:
    lib.replaceStrings
      [ "LLAMA_BUILD_NUMBER=11429" "LLAMA_BUILD_COMMIT=d812350" ]
      [ "LLAMA_BUILD_NUMBER=0" "LLAMA_BUILD_COMMIT=d6cf9ac" ]
      flag
  ) old.cmakeFlags;
  preConfigure =
    lib.replaceStrings [ "LLAMA_BUILD_NUMBER=11429" ] [ "LLAMA_BUILD_NUMBER=0" ]
      old.preConfigure;
})
