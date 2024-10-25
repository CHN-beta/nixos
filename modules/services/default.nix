inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.services = let inherit (inputs.lib) mkOption types; in
  {
    smartd.enable = mkOption { type = types.bool; default = false; };
    noisetorch.enable = mkOption { type = types.bool; default = inputs.config.nixos.system.gui.preferred; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (inputs.config.nixos) services;
      inherit (builtins) map listToAttrs toString;
    in mkMerge
    [
      (mkIf services.smartd.enable { services.smartd.enable = true; })
      (mkIf services.noisetorch.enable { programs.noisetorch.enable = true; })
    ];
}
