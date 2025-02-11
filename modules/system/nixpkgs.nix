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
          hostPlatform = if nixpkgs.march != null
            then { system = "x86_64-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; }
            else "x86_64-linux";
          cudaConfig = inputs.lib.optionalAttrs nixpkgs.cuda.enable
          (
            { cudaSupport = true; }
            // (inputs.lib.optionalAttrs (nixpkgs.cuda.capabilities != null)
              { cudaCapabilities = nixpkgs.cuda.capabilities; })
            // (inputs.lib.optionalAttrs (nixpkgs.cuda.forwardCompat != null)
              { cudaForwardCompat = nixpkgs.cuda.forwardCompat; })
          );
          allowInsecurePredicate = p: inputs.lib.warn
            "Allowing insecure package ${p.name or "${p.pname}-${p.version}"}" true;
        in
        {
          inherit hostPlatform;
          config = cudaConfig //
          {
            inherit allowInsecurePredicate;
            allowUnfree = true;
            qchem-config = { optArch = nixpkgs.march; useCuda = nixpkgs.cuda.enable; };
            android_sdk.accept_license = true;
          }
          // (if nixpkgs.march == null then {} else
          {
            # TODO: change znver4 after update oneapi
            # TODO: test znver3 do use AVX
            oneapiArch = let match = {};
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
                config = { allowUnfree = true; inherit allowInsecurePredicate; };
              };
            in
              { inherit genericPackages; }
              // (
                let
                  source =
                  {
                    "pkgs-23.11" = "nixpkgs-23.11";
                    "pkgs-23.05" = "nixpkgs-23.05";
                  };
                  packages = name: import inputs.topInputs.${source.${name}}
                  {
                    localSystem = hostPlatform;
                    config = cudaConfig //
                    {
                      allowUnfree = true;
                      # contentAddressedByDefault = true;
                      inherit allowInsecurePredicate;
                    };
                  };
                in builtins.listToAttrs (map
                  (name: { inherit name; value = packages name; }) (builtins.attrNames source))
              )
              // (
                inputs.lib.optionalAttrs (nixpkgs.march != null)
                {
                  # -march=xxx cause embree build failed
                  # https://github.com/embree/embree/issues/115
                  embree = prev.embree.override { stdenv = final.genericPackages.stdenv; };
                  simde = prev.simde.override { stdenv = final.genericPackages.stdenv; };
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
