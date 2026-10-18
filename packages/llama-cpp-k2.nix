{
  lib,
  llama-cpp,
  llama-cpp-k2-src,
}:
llama-cpp.overrideAttrs (old: {
  version = "0.6.0-k2-b11454";
  src = llama-cpp-k2-src;
  # b11454 already initializes the backend in test-llama-archs.cpp.
  patches = builtins.filter (
    patch: !lib.hasInfix "07ccce23cf7fe3c84e13d810accff672b1d966bf" (toString patch)
  ) (old.patches or [ ]);
  # tools/ui/package-lock.json is unchanged from v0.6.0, so retain npmDepsHash.
  cmakeFlags = map (
    flag:
    lib.replaceStrings
      [ "LLAMA_BUILD_NUMBER=11429" "LLAMA_BUILD_COMMIT=d812350" ]
      [ "LLAMA_BUILD_NUMBER=11454" "LLAMA_BUILD_COMMIT=4625240" ]
      flag
  ) old.cmakeFlags;
  preConfigure =
    lib.replaceStrings [ "LLAMA_BUILD_NUMBER=11429" ] [ "LLAMA_BUILD_NUMBER=11454" ]
      old.preConfigure;
})
