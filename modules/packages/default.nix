inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.packages.packages = let inherit (inputs.lib) mkOption types; in
  {
    _packages = mkOption { type = types.listOf types.unspecified; default = []; };
    _pythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    _prebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    _pythonEnvFlags = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    _vscodeEnvFlags = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
  };
  config =
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
  };
}
