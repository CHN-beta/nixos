inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.packages.packages = let inherit (inputs.lib) mkOption types; in
  {
    extraPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    excludePackages = mkOption { type = types.listOf types.unspecified; default = []; };
    extraPythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    excludePythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    extraPrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    excludePrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    _packages = mkOption { type = types.listOf types.unspecified; default = []; };
    _pythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    _prebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
  };
  config =
  {
    environment.systemPackages = with inputs.config.nixos.packages.packages;
      (inputs.lib.lists.subtractLists excludePackages (_packages ++ extraPackages))
      ++ [
        (inputs.pkgs.python3.withPackages (pythonPackages:
          inputs.lib.lists.subtractLists
            (builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
              excludePythonPackages))
            (builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
              (_pythonPackages ++ extraPythonPackages)))))
        (inputs.pkgs.writeTextDir "share/prebuild-packages"
          (builtins.concatStringsSep "\n" (builtins.map builtins.toString
            (inputs.lib.lists.subtractLists excludePrebuildPackages (_prebuildPackages ++ extraPrebuildPackages)))))
      ];
  };
}
