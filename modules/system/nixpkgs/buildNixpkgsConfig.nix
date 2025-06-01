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
  config = cudaConfig
    // {
      inherit allowInsecurePredicate;
      allowUnfree = true;
      android_sdk.accept_license = true;
      allowBroken = true;
    }
    // (inputs.lib.optionalAttrs (nixpkgs.march != null)
    {
      # TODO: test znver3 do use AVX
      oneapiArch = let match = {}; in match.${nixpkgs.march} or nixpkgs.march;
      nvhpcArch = nixpkgs.march;
      # contentAddressedByDefault = true;
    })
    // (inputs.lib.optionalAttrs (nixpkgs.nixRoot != null)
      { nix = { storeDir = "${nixpkgs.nixRoot}/store"; stateDir = "${nixpkgs.nixRoot}/var"; }; });
in platformConfig //
{
  inherit config;
  overlays =
  [
    inputs.topInputs.nur-xddxdd.overlays.inSubTree
    inputs.topInputs.nix-vscode-extensions.overlays.default
    inputs.topInputs.buildproxy.overlays.default
    (final: prev:
    {
      inherit (inputs.topInputs.nix-vscode-extensions.overlays.default final prev) nix-vscode-extensions;
      firefox-addons = (import "${inputs.topInputs.rycee}" { inherit (prev) pkgs; }).firefox-addons;
    })
    inputs.topInputs.self.overlays.default
    (final: prev:
      let
        inherit (final) system;
        genericPackages = import inputs.topInputs.nixpkgs
          { inherit system; config = { allowUnfree = true; inherit allowInsecurePredicate; }; };
      in
      {
        inherit genericPackages;
        telegram-desktop = prev.telegram-desktop.override
        {
          unwrapped = prev.telegram-desktop.unwrapped.overrideAttrs
            (prev: { patches = prev.patches or [] ++ [ ./telegram.patch ]; });
        };
        libvirt = (prev.libvirt.override { iptables = final.nftables; }).overrideAttrs
          (prev: { patches = prev.patches or [] ++ [ ./libvirt.patch ]; });
        root = (prev.root.override { stdenv = final.gcc13Stdenv; }).overrideAttrs (prev:
        {
          patches = prev.patches or [] ++ [ ./root.patch ];
          cmakeFlags = prev.cmakeFlags ++ [ "-DCMAKE_CXX_STANDARD=23" ];
        });
        inherit (final.pkgs-2411) iio-sensor-proxy;
      }
      // (
        let
          source =
          {
            pkgs-2305 = "nixpkgs-2305";
            pkgs-2311 = "nixpkgs-2311";
            pkgs-2411 = { source = "nixpkgs-2411"; overlay = inputs.topInputs.bscpkgs.overlays.default; };
            pkgs-unstable =
            {
              source = "nixpkgs-unstable";
              overlay = final: prev:
                (inputs.topInputs.self.overlays.default final prev);
                # {
                #   ollama = prev.ollama.override { cudaPackages = final.cudaPackages_12_8; };
                # }
                # // inputs.lib.optionalAttrs (nixpkgs.march != null)
                # {
                #   pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++ [(final: prev:
                #   {
                #     scipy = prev.scipy.overridePythonAttrs (prev:
                #       { disabledTests = prev.disabledTests or [] ++ [ "test_hyp2f1" ]; });
                #     rapidocr-onnxruntime = prev.rapidocr-onnxruntime.overridePythonAttrs { doCheck = false; };
                #     cfn-lint = prev.cfn-lint.overridePythonAttrs { doCheck = false; };
                #   })];
                #   rapidjson = prev.rapidjson.overrideAttrs { doCheck = false; };
                #   ctranslate2 = (prev.ctranslate2.override { withCUDA = false; withCuDNN = false; })
                #     .overrideAttrs (prev:
                #       { cmakeFlags = prev.cmakeFlags or [] ++ [ "-DENABLE_CPU_DISPATCH=OFF" ]; });
                #   valkey = prev.valkey.overrideAttrs { doCheck = false; };
                # }
                # // inputs.lib.optionalAttrs
                #   (builtins.elem nixpkgs.march [ "skylake" "silvermont" "broadwell" "znver3" ])
                #   { redis = prev.redis.overrideAttrs { doCheck = false; }; }
                # // inputs.lib.optionalAttrs (prev.stdenv.hostPlatform.avx2Support)
                # {
                #   haskellPackages = prev.haskellPackages.override
                #   {
                #     overrides = final: prev:
                #     {
                #       crypton = prev.crypton.overrideAttrs
                #         (prev: { configureFlags = prev.configureFlags or [] ++ [ "--ghc-option=-optc-mno-avx2" ]; });
                #     };
                #   };
                # }
                #   // (inputs.topInputs.self.overlays.default final prev);
            };
          };
          packages = name: import inputs.topInputs.${source.${name}.source or source.${name}}
          {
            localSystem = platformConfig.hostPlatform or { inherit (platformConfig) system; };
            inherit config;
            overlays = [(source.${name}.overlay or (_: _: {}))];
          };
        in builtins.listToAttrs (builtins.map
          (name: { inherit name; value = packages name; }) (builtins.attrNames source))
      )
      // (inputs.lib.optionalAttrs (prev.stdenv.hostPlatform.avx512Support)
        { gsl = prev.gsl.overrideAttrs { doCheck = false; }; })
      // (inputs.lib.optionalAttrs (nixpkgs.march != null && !prev.stdenv.hostPlatform.avx512Support)
        { libhwy = prev.libhwy.override { stdenv = final.genericPackages.stdenv; }; })
      // (inputs.lib.optionalAttrs (nixpkgs.march != null)
      {
        libinsane = prev.libinsane.overrideAttrs (prev:
          { nativeCheckInputs = builtins.filter (p: p.pname != "valgrind") prev.nativeCheckInputs; });
        lib2geom = prev.lib2geom.overrideAttrs (prev: { doCheck = false; });
        libreoffice-qt6-fresh = prev.libreoffice-qt6-fresh.override (prev:
          { unwrapped = prev.unwrapped.overrideAttrs (prev: { postPatch = prev.postPatch or "" +
          ''
            sed -i '/CPPUNIT_TEST.testDubiousArrayFormulasFODS/d' sc/qa/unit/functions_array.cxx
          '';});});
        libreoffice-still = prev.libreoffice-still.override (prev:
          { unwrapped = prev.unwrapped.overrideAttrs (prev: { postPatch = prev.postPatch or "" +
          ''
            sed -i '/CPPUNIT_TEST.testDubiousArrayFormulasFODS/d' sc/qa/unit/functions_array.cxx
          '';});});
        opencolorio = prev.opencolorio.overrideAttrs (prev: { doCheck = false; });
        openvswitch = prev.openvswitch.overrideAttrs (prev: { doCheck = false; });
        rapidjson = prev.rapidjson.overrideAttrs { doCheck = false; };
        valkey = prev.valkey.overrideAttrs { doCheck = false; };
        # -march=xxx cause embree build failed
        # https://github.com/embree/embree/issues/115
        embree = prev.embree.override { stdenv = final.genericPackages.stdenv; };
        simde = prev.simde.override { stdenv = final.genericPackages.stdenv; };
        pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++ [(final: prev:
        (
          {
            scipy = prev.scipy.overridePythonAttrs (prev:
              { disabledTests = prev.disabledTests or [] ++ [ "test_hyp2f1" ]; });
            rich = prev.rich.overridePythonAttrs (prev:
              { disabledTests = prev.disabledTests or [] ++ [ "test_brokenpipeerror" ]; });
            # paperwork-backend = prev.paperwork-backend.overrideAttrs (prev: { doCheck = false; });
          }
          # // (inputs.lib.optionalAttrs (nixpkgs.march != null && !prev.stdenv.hostPlatform.avx2Support)
          #   {
          #     numcodecs = prev.numcodecs.overridePythonAttrs (prev:
          #       { disabledTests = prev.disabledTests or [] ++ [ "test_encode_decode" "test_partial_decode" ]; });
          #   })
        ))];
        inherit (final.pkgs-2411) intelPackages_2023;
      })
      # // (inputs.lib.optionalAttrs (nixpkgs.march == "silvermont")
      #   { c-blosc = prev.c-blosc.overrideAttrs { doCheck = false; }; })
  )];
}
