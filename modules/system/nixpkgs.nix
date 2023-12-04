inputs:
{
  options.nixos.system.nixpkgs = let inherit (inputs.lib) mkOption types; in
  {
    march = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    cudaSupport = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (builtins) map listToAttrs filter tryEval;
      inherit (inputs.lib) mkIf;
      inherit (inputs.localLib) mkConditional attrsToList;
      inherit (inputs.config.nixos.system) nixpkgs;
    in
    {
      nixpkgs =
        let
          permittedInsecurePackages = map (package: package.name) (with inputs.pkgs;
            [ openssl_1_1 electron_19 python2 electron_12 electron_24 zotero ]);
          hostPlatform = mkConditional (nixpkgs.march != null)
            { system = "x86_64-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; }
            "x86_64-linux";
        in
        {
          inherit hostPlatform;
          config =
          {
            inherit permittedInsecurePackages;
            allowUnfree = true;
            cudaSupport = nixpkgs.cudaSupport;
            qchem-config = mkIf (nixpkgs.march != null) { optArch = nixpkgs.march; };
            oneapiArch = mkIf (nixpkgs.march != null) nixpkgs.march;
          };
          overlays =
          [(final: prev:
            let
              genericPackages = import inputs.topInputs.nixpkgs
              {
                system = "x86_64-linux";
                config = { allowUnfree = true; inherit permittedInsecurePackages; };
              };
            in
              { inherit genericPackages; }
              // {
                unstablePackages = import inputs.topInputs.nixpkgs-unstable
                { inherit hostPlatform; config.allowUnfree = true; };
              }
              // (
                let noBuildPackages = [ "chromium" "electron" "webkitgtk" ];
                in listToAttrs (filter
                  (package: let pname = tryEval package.value.pname or null;
                    in (pname.success && (builtins.elem pname.value noBuildPackages)))
                  (attrsToList genericPackages))
              )
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
              znver2 = "MZEN2";
              znver3 = "MZEN3";
            };
          in { GENERIC_CPU = inputs.lib.kernel.no; ${kernelConfig.${nixpkgs.march}} = inputs.lib.kernel.yes; };
      }];
    };
}
