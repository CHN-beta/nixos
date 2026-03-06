inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.packages =
    let
      inherit (inputs.lib) mkOption types;
      simpleSubmodule = mkOption { type = types.nullOr (types.submodule {}); default = null; };
    in
    {
      packages =
      {
        _packages = mkOption { type = types.listOf types.unspecified; default = []; };
        _pythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
        _prebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
        _pythonEnvFlags = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
        _vscodeEnvFlags = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      };
    }
    // (builtins.listToAttrs (builtins.map (n: inputs.lib.nameValuePair n simpleSubmodule)
      [ "vasp" "mathematica" "lumerical" "flatpak" "android-studio" ]));
  config = inputs.lib.mkMerge
  [
    {
      environment.systemPackages = with inputs.config.nixos.packages.packages;
        _packages
        ++ [
          (
            (inputs.pkgs.python3.withPackages (pythonPackages:
              builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages) _pythonPackages)))
            .override (prev: { makeWrapperArgs = prev.makeWrapperArgs or [] ++ _pythonEnvFlags; }))
          (inputs.pkgs.writeTextDir "share/prebuild-packages"
            (builtins.concatStringsSep "\n" (builtins.map builtins.toString _prebuildPackages)))
        ];
    }
    (inputs.lib.mkIf (inputs.config.nixos.packages.vasp != null)
    {
      nixos.packages.packages = with inputs.pkgs;
      {
        _packages =
        [
          localPackages.vasp.intel localPackages.vasp.vtst localPackages.vaspkit wannier90
          (if inputs.config.nixos.system.nixpkgs.cuda != null then localPackages.vasp.nvidia else emptyDirectory)
          localPackages.atomkit (inputs.lib.mkAfter localPackages.atat)
        ];
        _pythonPackages = [(ps: with ps; [ py4vasp ])];
      };
    })
    (inputs.lib.mkIf (inputs.config.nixos.packages.mathematica != null)
      { nixos.packages.packages._packages = [ inputs.pkgs.mathematica ]; })
    (inputs.lib.mkIf (inputs.config.nixos.packages.lumerical != null)
    {
      nixos =
      {
        packages.packages._packages = [ inputs.pkgs.localPackages.lumerical.lumerical.cmd ];
        services.lumericalLicenseManager = {};
      };
    })
    (inputs.lib.mkIf (inputs.config.nixos.packages.flatpak != null)
      { services.flatpak = { enable = true; uninstallUnmanaged = true; }; })
    (inputs.lib.mkIf (inputs.config.nixos.packages.android-studio != null)
      { nixos.packages.packages._packages = with inputs.pkgs; [ androidStudioPackages.stable.full ]; })
  ];
}
