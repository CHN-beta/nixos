{ localLib, lib, config, pkgs, ... }:
{
  imports = localLib.findModules ./.;
  options.nixos.packages =
    let simpleSubmodule = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
    in
    {
      python = lib.mkOption
      {
        type = lib.types.anything;
        default =
          let inherit (config.nixos.packages) pythonPackages pythonEnvFlags;
          in (pkgs.python3.withPackages (p: builtins.concatLists (builtins.map (f: f p) pythonPackages)))
            .override (prev: { makeWrapperArgs = prev.makeWrapperArgs or [] ++ pythonEnvFlags; });
        readOnly = true;
      };
      pythonPackages = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = []; };
      pythonEnvFlags = lib.mkOption { type = lib.types.listOf lib.types.nonEmptyStr; default = []; };
      vscodeEnvFlags = lib.mkOption { type = lib.types.listOf lib.types.nonEmptyStr; default = []; };
    }
    // (builtins.listToAttrs (builtins.map (n: lib.nameValuePair n simpleSubmodule)
      [ "vasp" "mathematica" "lumerical" "flatpak" "android-studio" ]));
  config = lib.mkMerge
  [
    { environment.systemPackages = [ config.nixos.packages.python ]; }
    (lib.mkIf (config.nixos.packages.vasp != null)
    {
      environment.systemPackages = with pkgs;
      [
        localPkgs.vasp.intel localPkgs.vasp.vtst localPkgs.vaspkit wannier90
        (if config.nixos.system.nixpkgs.cuda != null then localPkgs.vasp.nvidia else emptyDirectory)
        localPkgs.atomkit (lib.mkAfter localPkgs.atat)
      ];
      nixos.packages.pythonPackages = [(ps: with ps; [ py4vasp ])];
    })
    (lib.mkIf (config.nixos.packages.mathematica != null) { environment.systemPackages = [ pkgs.mathematica ]; })
    (lib.mkIf (config.nixos.packages.lumerical != null)
    {
      environment.systemPackages = [ pkgs.localPkgs.lumerical.lumerical.cmd ];
      nixos.services.lumericalLicenseManager = {};
    })
    (lib.mkIf (config.nixos.packages.flatpak != null)
      { services.flatpak = { enable = true; uninstallUnmanaged = true; }; })
    (lib.mkIf (config.nixos.packages.android-studio != null)
      { environment.systemPackages = [ pkgs.androidStudioPackages.stable.full ]; })
  ];
}
