{
  lib,
  llama-cpp,
  llama-cpp-inkling-src,
  cuda_nvml_dev,
}:
llama-cpp.overrideAttrs (old: {
  version = "b12649-mix-c7059d6";
  src = llama-cpp-inkling-src;
  # No inherited source-version patches or npm cache: this is an API-only worker.
  patches = [ ];
  buildInputs = old.buildInputs ++ [ cuda_nvml_dev ];
  nativeBuildInputs = builtins.filter (
    dependency: !(lib.hasInfix "npm-config-hook" (toString dependency))
  ) old.nativeBuildInputs;
  npmDeps = null;
  preConfigure = "";
  # The Inkling release archive does not ship the full tokenizer fixture set.
  ctestFlags = (old.ctestFlags or [ ]) ++ [
    "--exclude-regex"
    "^test-tokenizer-0-"
  ];
  cmakeFlags =
    builtins.filter (
      flag: !(lib.hasPrefix "-DLLAMA_BUILD_NUMBER" flag || lib.hasPrefix "-DLLAMA_BUILD_COMMIT" flag)
    ) old.cmakeFlags
    ++ [
      "-DLLAMA_BUILD_NUMBER=12649"
      "-DLLAMA_BUILD_COMMIT=189f431bf"
      "-DLLAMA_BUILD_UI=OFF"
      "-DLLAMA_USE_PREBUILT_UI=OFF"
    ];
})
