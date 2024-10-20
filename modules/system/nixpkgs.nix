inputs:
{
  options.nixos.system.nixpkgs = let inherit (inputs.lib) mkOption types; in
  {
    arch = mkOption { type = types.enum [ "x86_64" "aarch64" ]; default = "x86_64"; };
    march = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    cuda =
    {
      enable = mkOption { type = types.bool; default = false; };
      capabilities = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
      forwardCompat = mkOption { type = types.nullOr types.bool; default = null; };
    };
  };
  config =
    let
      inherit (builtins) map listToAttrs filter tryEval attrNames concatStringsSep toString;
      inherit (inputs.lib) mkIf mkMerge;
      inherit (inputs.lib.strings) hasPrefix splitString;
      inherit (inputs.localLib) mkConditional attrsToList;
      inherit (inputs.config.nixos.system) nixpkgs;
    in
    {
      nixpkgs =
        let
          permittedInsecurePackages =
            [ "openssl_1_1" "python2" "zotero"  "electron_27" "electron_28" "olm" "fluffychat" ];
          hostPlatform = if nixpkgs.march != null
            then { system = "${nixpkgs.arch}-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; }
            else "${nixpkgs.arch}-linux";
          cudaConfig = inputs.lib.optionalAttrs nixpkgs.cuda.enable
          (
            { cudaSupport = true; }
            // (inputs.lib.optionalAttrs (nixpkgs.cuda.capabilities != null)
              { cudaCapabilities = nixpkgs.cuda.capabilities; })
            // (inputs.lib.optionalAttrs (nixpkgs.cuda.forwardCompat != null)
              { cudaForwardCompat = nixpkgs.cuda.forwardCompat; })
          );
        in
        {
          inherit hostPlatform;
          config = cudaConfig //
          {
            permittedInsecurePackages = map (package: inputs.pkgs.${package}.name) permittedInsecurePackages;
            allowUnfree = true;
            qchem-config = { optArch = nixpkgs.march; useCuda = nixpkgs.cuda.enable; };
          }
          // (if nixpkgs.march == null then {} else
          {
            # TODO: change znver4 after update oneapi
            # TODO: test znver3 do use AVX
            oneapiArch = let match = { znver3 = "CORE-AVX2"; znver4 = "core-avx2"; };
              in match.${nixpkgs.march} or nixpkgs.march;
            nvhpcArch = nixpkgs.march;
            # contentAddressedByDefault = true;
            enableCcache = true;
          });
          overlays =
          [(final: prev:
            let
              inherit (final) system;
              genericPackages = import inputs.topInputs.nixpkgs
              {
                inherit system;
                config =
                {
                  allowUnfree = true;
                  permittedInsecurePackages = let pkgs = inputs.topInputs.nixpkgs.legacyPackages.${system}; in map
                    (package: pkgs.${package}.name)
                    (filter (package: pkgs ? ${package}) permittedInsecurePackages);
                };
              };
            in
              { inherit genericPackages; }
              // (
                let
                  source =
                  {
                    "pkgs-23.11" = "nixpkgs-23.11";
                    "pkgs-23.05" = "nixpkgs-23.05";
                    "pkgs-22.11" = "nixpkgs-22.11";
                    "pkgs-22.05" = "nixpkgs-22.05";
                  };
                  permittedInsecurePackages."pkgs-23.11" = [ "electron_19" ];
                  packages = name: import inputs.topInputs.${source.${name}}
                  {
                    localSystem = hostPlatform;
                    config = cudaConfig //
                    {
                      allowUnfree = true;
                      # contentAddressedByDefault = true;
                      permittedInsecurePackages =
                        let pkgs = inputs.topInputs.${source.${name}}.legacyPackages.${system};
                        in map
                          (package: pkgs.${package}.name)
                          permittedInsecurePackages.${name} or [];
                    };
                  };
                in builtins.listToAttrs (map
                  (name: { inherit name; value = packages name; }) (builtins.attrNames source))
              )
              // (
                inputs.lib.optionalAttrs (nixpkgs.march != null)
                {
                  embree = prev.embree.override { stdenv = final.genericPackages.stdenv; };
                  libvorbis = prev.libvorbis.override { stdenv = final.genericPackages.stdenv; };
                  _7zz = prev._7zz.override { stdenv = final.genericPackages.stdenv; };
                  ispc = genericPackages.ispc;
                  opencolorio = prev.opencolorio.overrideAttrs { doCheck = false; };
                  redis = prev.redis.overrideAttrs { doCheck = false; };
                  krita = final.genericPackages.krita;
                  geos = prev.geos.overrideAttrs { doCheck = false; };
                  c-blosc = prev.c-blosc.overrideAttrs { doCheck = false; };
                  binaryen = prev.binaryen.overrideAttrs
                    { cmakeFlags = (prev.cmakeFlags or []) ++ [ "-DCMAKE_CXX_FLAGS=-Wno-maybe-uninitialized" ]; };
                  fwupd = prev.fwupd.overrideAttrs { doCheck = false; };
                  rapidjson = prev.rapidjson.overrideAttrs { doCheck = false; };
                  scalapack = prev.scalapack.overrideAttrs { doCheck = false; };
                  xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (prev:
                    { doCheck = false; nativeBuildInputs = prev.nativeBuildInputs ++ prev.nativeCheckInputs; });
                  gsl = prev.gsl.overrideAttrs { doCheck = false; };
                  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [(final: prev:
                  {
                    numcodecs = prev.numcodecs.overridePythonAttrs { doCheck = false; };
                    zarr = prev.zarr.overridePythonAttrs (prev:
                      { disabledTests = prev.disabledTests or [] ++ [ "test_encode_decode_array_dtype_shape_v3" ]; });
                  })];
                  nodejs = prev.nodejs.overrideAttrs { doCheck = false; };
                }
              )
              // (
                inputs.lib.optionalAttrs nixpkgs.cuda.enable
                {
                  waifu2x-converter-cpp = prev.waifu2x-converter-cpp.override
                    { stdenv = final.cudaPackages.backendStdenv; };
                }
              )
          )];
        };
      programs.ccache = { enable = true; cacheDir = "/var/lib/ccache"; };
      nix.settings.extra-sandbox-paths = [ inputs.config.programs.ccache.cacheDir ];
      boot.kernelPatches = mkIf (nixpkgs.march != null && inputs.config.nixos.system.kernel.variant != "steamos")
      [{
        name = "native kernel";
        patch = null;
        extraStructuredConfig =
          let kernelConfig = { znver2 = "MZEN2"; znver3 = "MZEN3"; znver4 = "MZEN4"; };
          in
          {
            GENERIC_CPU = inputs.lib.kernel.no;
            ${kernelConfig.${nixpkgs.march} or "M${inputs.lib.toUpper nixpkgs.march}"} = inputs.lib.kernel.yes;
          };
      }];
    };
}
