inputs:
{
  options.nixos.system.nixpkgs = let inherit (inputs.lib) mkOption types; in
  {
    march = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
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
          overlays = [(final: prev: { genericPackages =
            import inputs.topInputs.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };})];
        };
      }
      (
        mkConditional (nixpkgs.march != null)
        {
          nixpkgs =
          {
            hostPlatform = { system = "x86_64-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; };
            config.qchem-config.optArch = nixpkgs.march;
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
              in
              {
                GENERIC_CPU = inputs.lib.kernel.no;
                ${kernelConfig.${nixpkgs.march}} = inputs.lib.kernel.yes;
              };
          }];
        }
        { nixpkgs.hostPlatform = "x86_64-linux"; }
      )
    ];
}
