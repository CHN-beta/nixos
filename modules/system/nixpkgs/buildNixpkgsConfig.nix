# inputs = { lib, topInputs, ...}; nixpkgs = { march, cuda, nixRoot };
{ inputs, nixpkgs }:
let
  platformConfig =
    if nixpkgs.march == null then { system = "x86_64-linux"; }
    else { hostPlatform = { system = "x86_64-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; }; };
  cudaConfig = inputs.lib.optionalAttrs (nixpkgs.cuda != null)
  (
    { cudaSupport = true; }
    // (inputs.lib.optionalAttrs (nixpkgs.cuda.capabilities != null)
      { cudaCapabilities = nixpkgs.cuda.capabilities; })
    // (inputs.lib.optionalAttrs (nixpkgs.cuda.forwardCompat != null)
      { cudaForwardCompat = nixpkgs.cuda.forwardCompat; })
  );
  allowInsecurePredicate = p: inputs.lib.warn "Allowing insecure package ${p.name or "${p.pname}-${p.version}"}" true;
in platformConfig //
{
  config = cudaConfig //
  {
    inherit allowInsecurePredicate;
    allowUnfree = true;
    qchem-config = { optArch = nixpkgs.march; useCuda = nixpkgs.cuda != null; };
    android_sdk.accept_license = true;
  }
  // (inputs.lib.optionalAttrs (nixpkgs.march != null)
  {
    # TODO: change znver4 after update oneapi
    # TODO: test znver3 do use AVX
    oneapiArch = let match = {}; in match.${nixpkgs.march} or nixpkgs.march;
    nvhpcArch = nixpkgs.march;
    # contentAddressedByDefault = true;
    enableCcache = true;
  })
  // (inputs.lib.optionalAttrs (nixpkgs.nixRoot != null)
    { nix = { storeDir = "${nixpkgs.nixRoot}/store"; stateDir = "${nixpkgs.nixRoot}/var"; }; });
  overlays =
  [(final: prev:
    let
      inherit (final) system;
      genericPackages = import inputs.topInputs.nixpkgs
        { inherit system; config = { allowUnfree = true; inherit allowInsecurePredicate; }; };
    in
      {
        inherit genericPackages;
        telegram-desktop = prev.telegram-desktop.override
        {
          unwrapped = prev.telegram-desktop.unwrapped.overrideAttrs (prev:
            { patches = prev.patches or [] ++ [ ./telegram.patch ]; });
        };
      }
      // (
        let
          source =
          {
            "pkgs-23.11" = "nixpkgs-23.11";
            "pkgs-23.05" = "nixpkgs-23.05";
            pkgs-unstable =
            {
              source = "nixpkgs-unstable";
              overlay = final: prev:
                {
                  ollama = prev.ollama.override { cudaPackages = final.cudaPackages_12_8; };
                }
                // inputs.lib.optionalAttrs (nixpkgs.march != null)
                {
                  pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++ [(final: prev:
                  {
                    scipy = prev.scipy.overridePythonAttrs (prev:
                      { disabledTests = prev.disabledTests or [] ++ [ "test_hyp2f1" ]; });
                    rapidocr-onnxruntime = prev.rapidocr-onnxruntime.overridePythonAttrs { doCheck = false; };
                    cfn-lint = prev.cfn-lint.overridePythonAttrs { doCheck = false; };
                  })];
                  rapidjson = prev.rapidjson.overrideAttrs { doCheck = false; };
                  ctranslate2 = (prev.ctranslate2.override { withCUDA = false; withCuDNN = false; })
                    .overrideAttrs (prev:
                      { cmakeFlags = prev.cmakeFlags or [] ++ [ "-DENABLE_CPU_DISPATCH=OFF" ]; });
                }
                // inputs.lib.optionalAttrs
                  (builtins.elem nixpkgs.march [ "skylake" "silvermont" "broadwell" "znver3" ])
                  { redis = prev.redis.overrideAttrs { doCheck = false; }; };
            };
          };
          packages = name: import inputs.topInputs.${source.${name}.source or source.${name}}
          {
            localSystem = platformConfig.hostPlatform or { inherit (platformConfig) system; };
            config = cudaConfig //
            {
              allowUnfree = true;
              # contentAddressedByDefault = true;
              inherit allowInsecurePredicate;
            };
            overlays = [(source.${name}.overlay or (_: _: {}))];
          };
        in builtins.listToAttrs (builtins.map
          (name: { inherit name; value = packages name; }) (builtins.attrNames source))
      )
      // (inputs.lib.optionalAttrs (nixpkgs.march != null)
      {
        # -march=xxx cause embree build failed
        # https://github.com/embree/embree/issues/115
        embree = prev.embree.override { stdenv = final.genericPackages.stdenv; };
        simde = prev.simde.override { stdenv = final.genericPackages.stdenv; };
      })
      // (inputs.lib.optionalAttrs (nixpkgs.march == "silvermont")
        { c-blosc = prev.c-blosc.overrideAttrs { doCheck = false; }; })
  )];
}
