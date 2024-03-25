inputs:
{
  options.nixos.system.nixpkgs = let inherit (inputs.lib) mkOption types; in
  {
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
            [ "openssl_1_1" "electron_19" "python2" "electron_12" "electron_24" "zotero" "electron_25" ];
          hostPlatform = if nixpkgs.march != null
            then { inherit (inputs.pkgs) system; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; }
            else inputs.pkgs.system;
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
            permittedInsecurePackages = map
              (package: inputs.pkgs.${package}.name)
              (filter (package: inputs.pkgs ? ${package}) permittedInsecurePackages);
            allowUnfree = true;
            qchem-config = { optArch = nixpkgs.march; useCuda = nixpkgs.cuda.enable; };
          }
          // (if nixpkgs.march == null then {} else
          {
            oneapiArch = let match = { znver3 = "CORE-AVX2"; znver4 = "CORE-AVX512"; };
              in match.${nixpkgs.march} or nixpkgs.march;
            nvhpcArch = nixpkgs.march;
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
                    unstablePackages = "nixpkgs-unstable";
                    "pkgs-23.05" = "nixpkgs-23.05";
                    "pkgs-22.11" = "nixpkgs-22.11";
                    "pkgs-22.05" = "nixpkgs-22.05";
                  };
                  packages = name: import inputs.topInputs.${source.${name}}
                  {
                    localSystem = hostPlatform;
                    config = cudaConfig //
                    {
                      allowUnfree = true;
                      permittedInsecurePackages =
                        let pkgs = inputs.topInputs.${source.${name}}.legacyPackages.${system};
                        in map
                          (package: pkgs.${package}.name)
                          (filter (package: pkgs ? ${package}) permittedInsecurePackages);
                    };
                  };
                in builtins.listToAttrs (map
                  (name: { inherit name; value = packages name; }) (builtins.attrNames source))
              )
              // (inputs.lib.optionalAttrs (nixpkgs.march != null)
                  { embree = prev.embree.override { stdenv = final.genericPackages.stdenv; }; })
          )];
        };
      programs.ccache = { enable = true; cacheDir = "/var/lib/ccache"; };
      nix.settings.extra-sandbox-paths = [ inputs.config.programs.ccache.cacheDir ];
      boot.kernelPatches = mkIf (nixpkgs.march != null)
      [{
        name = "native kernel";
        patch = null;
        extraStructuredConfig =
          let
            kernelConfig =
            {
              alderlake = "MALDERLAKE";
              sandybridge = "MSANDYBRIDGE";
              silvermont = "MSILVERMONT";
              broadwell = "MBROADWELL";
              skylake = "MSKYLAKE";
              znver2 = "MZEN2";
              znver3 = "MZEN3";
              znver4 = "MZEN4";
            };
          in { GENERIC_CPU = inputs.lib.kernel.no; ${kernelConfig.${nixpkgs.march}} = inputs.lib.kernel.yes; };
      }];
      environment.systemPackages = mkIf nixpkgs.cuda.enable [ inputs.pkgs.cudatoolkit ];
    };
}
