inputs:
{
  options.nixos.system.nixpkgs = let inherit (inputs.lib) mkOption types; in
  {
    march = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    oneapiArch = mkOption
    {
      type = types.nullOr types.nonEmptyStr;
      default = inputs.config.nixos.system.nixpkgs.march;
    };
    cudaSupport = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) mkConditional;
      inherit (inputs.config.nixos.system) nixpkgs;
    in mkMerge
    [
      {
        nixpkgs =
        {
          config.allowUnfree = true;
          config.cudaSupport = nixpkgs.cudaSupport;
          overlays = [(final: prev:
          {
            genericPackages =
              import inputs.topInputs.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
          })];
        };
      }
      (
        mkConditional (nixpkgs.march != null)
        {
          programs.ccache = { enable = true; cacheDir = "/var/lib/ccache"; };
          nix.settings.extra-sandbox-paths = [ inputs.config.programs.ccache.cacheDir ];
          nixpkgs =
          {
            hostPlatform = { system = "x86_64-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; };
            config = { qchem-config.optArch = nixpkgs.march; oneapiArch = nixpkgs.oneapiArch; enableCcache = true; };
            overlays = [(final: prev:
            {
              unstablePackages = import inputs.topInputs.nixpkgs-unstable
              {
                localSystem = { system = "x86_64-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; };
                config.allowUnfree = true;
              };
            })];
          };
          boot.kernelPatches =
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
                  znver2 = "MZEN2";
                  znver3 = "MZEN3";
                };
              in { GENERIC_CPU = inputs.lib.kernel.no; ${kernelConfig.${nixpkgs.march}} = inputs.lib.kernel.yes; };
          }];
        }
        {
          nixpkgs =
          {
            hostPlatform = "x86_64-linux";
            overlays = [(final: prev: { unstablePackages = import inputs.topInputs.nixpkgs-unstable
              { localSystem.system = "x86_64-linux"; config.allowUnfree = true; }; })];
          };
        }
      )
    ];
}
