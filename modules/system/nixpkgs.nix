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
    replaceTensorflow = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (builtins) map listToAttrs filter tryEval attrNames concatStringsSep toString;
      inherit (inputs.lib) mkIf mkMerge;
      inherit (inputs.lib.strings) hasPrefix splitString;
      inherit (inputs.localLib) mkConditional attrsToList;
      inherit (inputs.config.nixos.system) nixpkgs;
    in mkMerge
    [
      {
        nixpkgs =
          let
            permittedInsecurePackages =
              [ "openssl_1_1" "electron_19" "python2" "electron_12" "electron_24" "zotero" ];
            hostPlatform = mkConditional (nixpkgs.march != null)
              { system = "x86_64-linux"; gcc = { arch = nixpkgs.march; tune = nixpkgs.march; }; }
              "x86_64-linux";
            noBuildPackages =
            [
              # chromium
              "chromium" "electron" "webkitgtk"
              # old python release
              "python310"
              # nodejs
              "nodejs"
              # haskell
              "haskell"
              # libreoffice
              "libreoffice" "libreoffice-qt" "libreoffice-fresh"
              # java
              "openjdk" "jetbrains"
            ];
          in
          {
            inherit hostPlatform;
            config =
            {
              permittedInsecurePackages = map
                (package: inputs.pkgs.${package}.name)
                (filter (package: inputs.pkgs ? ${package}) permittedInsecurePackages);
              allowUnfree = true;
              qchem-config = mkIf (nixpkgs.march != null) { optArch = nixpkgs.march; };
              oneapiArch = mkIf (nixpkgs.march != null) nixpkgs.march;
            };
            overlays =
            [(final: prev:
              let
                genericPackages = import inputs.topInputs.nixpkgs
                {
                  system = "x86_64-linux";
                  config =
                  {
                    allowUnfree = true;
                    permittedInsecurePackages = let pkgs = inputs.topInputs.nixpkgs.legacyPackages.x86_64-linux; in map
                      (package: pkgs.${package}.name)
                      (filter (package: pkgs ? ${package}) permittedInsecurePackages);
                  };
                };
                targetPythonVersion = inputs.lib.lists.take 2 (splitString "." genericPackages.python3.version);
                targetPythonName = "python${concatStringsSep "" targetPythonVersion}";
              in
                { inherit genericPackages; }
                // {
                  unstablePackages = import inputs.topInputs.nixpkgs-unstable
                  {
                    localSystem = hostPlatform;
                    config =
                    {
                      allowUnfree = true;
                      permittedInsecurePackages =
                        let pkgs = inputs.topInputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
                        in map
                          (package: pkgs.${package}.name)
                          (filter (package: pkgs ? ${package}) permittedInsecurePackages);
                    };
                  };
                }
                // (
                  if nixpkgs.march != null then
                    let replacedPackages = filter
                      (package: let pname = tryEval genericPackages.${package}.pname or null;
                        in (pname.success && (builtins.elem pname.value noBuildPackages)
                          || builtins.elem package noBuildPackages))
                      (filter
                        (package: builtins.any (prefix: hasPrefix prefix package) noBuildPackages)
                        (attrNames genericPackages));
                    in listToAttrs (map
                      (package: { name = package; value = genericPackages.${package}; })
                      replacedPackages)
                  else {}
                )
                // (
                  if nixpkgs.replaceTensorflow then
                  {
                    ${targetPythonName} = prev.${targetPythonName}.override { packageOverrides = final: prev:
                    {
                      tensorflow = prev.tensorflow.override
                      {
                        cudaSupport = false;
                        customBazelBuild = genericPackages.${targetPythonName}.pkgs.tensorflow.passthru.bazel-build;
                      };
                    };};
                  }
                  else {}
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
      }
      {
        nixpkgs.config = mkIf nixpkgs.cuda.enable
        (
          { cudaSupport = true; }
            // (if nixpkgs.cuda.capabilities != null then { cudaCapabilities = nixpkgs.cuda.capabilities; } else {})
            // (if nixpkgs.cuda.forwardCompat != null then { cudaForwardCompat = nixpkgs.cuda.forwardCompat; }
              else {}));
      }
    ];
}
