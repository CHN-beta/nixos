{ localLib, lib, config, pkgs, ... }:
{
  imports = localLib.findModules ./.;
  options.nixos.packages =
    let simpleSubmodule = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
    in
    {
      packages =
      {
        _packages = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = []; };
        _pythonPackages = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = []; };
        _prebuildPackages = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = []; };
        _pythonEnvFlags = lib.mkOption { type = lib.types.listOf lib.types.nonEmptyStr; default = []; };
        _vscodeEnvFlags = lib.mkOption { type = lib.types.listOf lib.types.nonEmptyStr; default = []; };
      };
    }
    // (builtins.listToAttrs (builtins.map (n: lib.nameValuePair n simpleSubmodule)
      [ "vasp" "mathematica" "lumerical" "flatpak" "android-studio" ]));
  config = lib.mkMerge
  [
    {
      environment.systemPackages = with config.nixos.packages.packages;
        _packages
        ++ [
          (
            (pkgs.python3.withPackages (pythonPackages:
              builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages) _pythonPackages)))
            .override (prev: { makeWrapperArgs = prev.makeWrapperArgs or [] ++ _pythonEnvFlags; }))
          (pkgs.writeTextDir "share/prebuild-packages"
            (builtins.concatStringsSep "\n" (builtins.map builtins.toString _prebuildPackages)))
        ];
    }
    (lib.mkIf (config.nixos.packages.vasp != null)
    {
      nixos.packages.packages = with pkgs;
      {
        _packages =
        [
          localPackages.vasp.intel localPackages.vasp.vtst localPackages.vaspkit wannier90
          (if config.nixos.system.nixpkgs.cuda != null then localPackages.vasp.nvidia else emptyDirectory)
          localPackages.atomkit (lib.mkAfter localPackages.atat)
        ];
        _pythonPackages = [(ps: with ps; [ py4vasp ])];
      };
    })
    (lib.mkIf (config.nixos.packages.mathematica != null)
      { nixos.packages.packages._packages = [ pkgs.mathematica ]; })
    (lib.mkIf (config.nixos.packages.lumerical != null)
    {
      nixos =
      {
        packages.packages._packages = [ pkgs.localPackages.lumerical.lumerical.cmd ];
        services.lumericalLicenseManager = {};
      };
    })
    (lib.mkIf (config.nixos.packages.flatpak != null)
      { services.flatpak = { enable = true; uninstallUnmanaged = true; }; })
    (lib.mkIf (config.nixos.packages.android-studio != null)
      { nixos.packages.packages._packages = with pkgs; [ androidStudioPackages.stable.full ]; })
  ];
}
