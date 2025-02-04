inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.services = let inherit (inputs.lib) mkOption types; in
  {
    smartd = mkOption { type = types.nullOr (types.submodule {}); default = {}; };
    noisetorch = mkOption
    {
      type = types.nullOr (types.submodule {});
      default = if inputs.config.nixos.model.type == "desktop" then {} else null;
    };
  };
  config = let inherit (inputs.config.nixos.services) smartd noisetorch; in inputs.lib.mkMerge
  [
    (inputs.lib.mkIf (smartd != null) { services.smartd.enable = true; })
    (inputs.lib.mkIf (noisetorch != null) { programs.noisetorch.enable = true; })
  ];
}
