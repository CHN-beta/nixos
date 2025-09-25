# inputs = { lib, topInputs, ...}; nixpkgs = { march, cuda, nixRoot, nixos, arch, rocm };
{ inputs, nixpkgs }:
let
  platformConfig =
    if nixpkgs.march == null then { system = "${nixpkgs.arch or "x86_64"}-linux"; }
    else
    {
      ${if nixpkgs.nixos then "hostPlatform" else "localSystem"} =
        { system = "${nixpkgs.arch or "x86_64"}-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; };
    };
  cudaConfig = inputs.lib.optionalAttrs (nixpkgs.cuda or null != null)
  (
    { cudaSupport = true; }
    // (inputs.lib.optionalAttrs (nixpkgs.cuda.capabilities != null)
      { cudaCapabilities = nixpkgs.cuda.capabilities; })
    // (inputs.lib.optionalAttrs (nixpkgs.cuda.forwardCompat != null)
      { cudaForwardCompat = nixpkgs.cuda.forwardCompat; })
  );
  rocmConfig = inputs.lib.optionalAttrs (nixpkgs.rocm or false) { rocmSupport = true; };
  allowInsecurePredicate = p: inputs.lib.warn "Allowing insecure package ${p.name or "${p.pname}-${p.version}"}" true;
  config = cudaConfig // rocmConfig
    // {
      inherit allowInsecurePredicate;
      allowUnfree = true;
      android_sdk.accept_license = true;
      allowBroken = true;
    }
    // (inputs.lib.optionalAttrs (nixpkgs.march != null)
    {
      oneapiArch = let match.znver5 = "znver4"; in match.${nixpkgs.march} or nixpkgs.march;
      nvhpcArch = nixpkgs.march;
      # contentAddressedByDefault = true;
    })
    // (inputs.lib.optionalAttrs (nixpkgs.nixRoot or null != null)
      { nix = { storeDir = "${nixpkgs.nixRoot}/store"; stateDir = "${nixpkgs.nixRoot}/state"; }; });
in platformConfig //
{
  inherit config;
  overlays =
  [
    inputs.topInputs.aagl.overlays.default
    inputs.topInputs.nur-xddxdd.overlays.inSubTree
    inputs.topInputs.buildproxy.overlays.default
    inputs.topInputs.nix4vscode.overlays.default
    inputs.topInputs.bscpkgs.overlays.default
    (final: prev:
    {
      nur-linyinfeng = (inputs.topInputs.nur-linyinfeng.overlays.default final prev).linyinfeng;
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
        root = prev.root.overrideAttrs (prev: { cmakeFlags = prev.cmakeFlags ++ [ "-DCMAKE_CXX_STANDARD=23" ]; });
        boost188 = prev.boost188.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./boost188.patch ]; });
      }
      // (
        let
          marchFilter = version:
            # old version of nixpkgs does not recognize znver5, use znver4 instead
            inputs.lib.optionalAttrs (inputs.lib.versionOlder version "25.05") { znver5 = "znver4"; };
          source =
          {
            pkgs-2305 = "nixpkgs-2305";
            pkgs-2311 = "nixpkgs-2311";
            pkgs-2411 = "nixpkgs-2411";
            # pkgs-unstable =
            # {
            #   source = "nixpkgs-unstable";
            #   overlays =
            #   [
            #     inputs.topInputs.self.overlays.default
            #     (_: _:
            #     {
            #       genericPackages = import inputs.topInputs.nixpkgs-unstable
            #         { inherit system; config = { allowUnfree = true; inherit allowInsecurePredicate; }; };
            #     })
            #   ];
            # };
          };
          packages = name:
            let flakeSource = inputs.topInputs.${source.${name}.source or source.${name}};
            in import flakeSource
            {
              localSystem =
                if nixpkgs.march == null then { system = "${nixpkgs.arch or "x86_64"}-linux"; }
                else
                  let march = (marchFilter flakeSource.lib.version).${nixpkgs.march} or nixpkgs.march;
                  in { system = "${nixpkgs.arch or "x86_64"}-linux"; gcc = { arch = march; tune = march; }; };
              inherit config;
              overlays = source.${name}.overlays or [(_: _: {})];
            };
        in builtins.listToAttrs (builtins.map
          (name: { inherit name; value = packages name; }) (builtins.attrNames source))
      )
      // (inputs.lib.optionalAttrs (prev.stdenv.hostPlatform.avx512Support)
        { gsl = prev.gsl.overrideAttrs { doCheck = false; }; })
      # // (inputs.lib.optionalAttrs (nixpkgs.march != null && !prev.stdenv.hostPlatform.avx512Support)
      #   { libhwy = prev.libhwy.override { stdenv = final.genericPackages.stdenv; }; })
      // (inputs.lib.optionalAttrs (nixpkgs.march != null)
      {
        assimp = prev.assimp.override { stdenv = final.genericPackages.stdenv; };
        redis = prev.redis.overrideAttrs (prev: { doCheck = false; });
        wannier90 = prev.wannier90.overrideAttrs { buildFlags = [ "dynlib" ]; };
        xen = prev.xen.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./xen.patch ]; });
      #   libinsane = prev.libinsane.overrideAttrs (prev:
      #     { nativeCheckInputs = builtins.filter (p: p.pname != "valgrind") prev.nativeCheckInputs; });
        lib2geom = prev.lib2geom.overrideAttrs (prev: { doCheck = false; });
        libreoffice-qt6-fresh-unwrapped = prev.libreoffice-qt6-fresh-unwrapped.overrideAttrs
          (prev: { postPatch = prev.postPatch or "" +
          ''
            sed -i '/CPPUNIT_TEST.testDubiousArrayFormulasFODS/d' sc/qa/unit/functions_array.cxx
          '';});
      #   libreoffice-still = prev.libreoffice-still.override (prev:
      #     { unwrapped = prev.unwrapped.overrideAttrs (prev: { postPatch = prev.postPatch or "" +
      #     ''
      #       sed -i '/CPPUNIT_TEST.testDubiousArrayFormulasFODS/d' sc/qa/unit/functions_array.cxx
      #     '';});});
        opencolorio = prev.opencolorio.overrideAttrs (prev: { doCheck = false; });
      #   openvswitch = prev.openvswitch.overrideAttrs (prev: { doCheck = false; });
        rapidjson = prev.rapidjson.overrideAttrs { doCheck = false; };
      #   valkey = prev.valkey.overrideAttrs { doCheck = false; };
      #   # -march=xxx cause embree build failed
      #   # https://github.com/embree/embree/issues/115
      #   embree = prev.embree.override { stdenv = final.genericPackages.stdenv; };
        simde = prev.simde.override { stdenv = final.genericPackages.stdenv; };
      #   ctranslate2 = prev.ctranslate2.overrideAttrs (prev:
      #     { cmakeFlags = prev.cmakeFlags or [] ++ [ "-DENABLE_CPU_DISPATCH=OFF" ]; });
        pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++ [(final: prev:
        (
          { picosvg = prev.picosvg.overridePythonAttrs { doCheck = false; }; }
          # {
          #   scipy = prev.scipy.overridePythonAttrs (prev:
          #     { disabledTests = prev.disabledTests or [] ++ [ "test_hyp2f1" ]; });
          #   rich = prev.rich.overridePythonAttrs (prev:
          #     { disabledTests = prev.disabledTests or [] ++ [ "test_brokenpipeerror" ]; });
          # }
          # // (inputs.lib.optionalAttrs (nixpkgs.march != null && !prev.stdenv.hostPlatform.avx2Support)
          # {
          #   numcodecs = prev.numcodecs.overridePythonAttrs (prev:
          #   {
          #     disabledTests = prev.disabledTests or []
          #       ++ [ "test_encode_decode" "test_partial_decode" "test_blosc" ];
          #   });
          # })
        ))];
      #   inherit (final.pkgs-2411) intelPackages_2023;
      })
      # // (inputs.lib.optionalAttrs (nixpkgs.march == "silvermont")
      #   { c-blosc = prev.c-blosc.overrideAttrs { doCheck = false; }; })
      # // (inputs.lib.optionalAttrs (nixpkgs.arch or null == "aarch64") { nix = final.nixVersions.nix_2_29; })
  )];
}
