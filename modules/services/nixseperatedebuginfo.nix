inputs:
{
  options.nixos.services.nixseparatedebuginfo = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if builtins.elem "desktop-extra" inputs.config.nixos.packages._packageSets then {} else null;
  };
  config =
    let inherit (inputs.config.nixos.services) nixseparatedebuginfo; in inputs.lib.mkIf (nixseparatedebuginfo != {})
    {
      services.nixseparatedebuginfod.enable = true;
      environment.persistence =
        let inherit (inputs.config.nixos.system) impermanence; in inputs.lib.mkIf impermanence.enable
        {
          "${impermanence.nodatacow}".directories = let user = "nixseparatedebuginfod"; in
          [{ directory = "/var/cache/nixseparatedebuginfod"; inherit user; group = user; mode = "0755"; }];
        };
    };
}
