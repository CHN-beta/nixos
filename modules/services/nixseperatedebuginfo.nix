inputs:
{
  options.nixos.services.nixseparatedebuginfo = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config =
    let inherit (inputs.config.nixos.services) nixseparatedebuginfo; in inputs.lib.mkIf (nixseparatedebuginfo != null)
    {
      services.nixseparatedebuginfod.enable = true;
      environment.persistence."/nix/nodatacow".directories =
      [{
        directory = "/var/cache/nixseparatedebuginfod";
        user = "nixseparatedebuginfod";
        group = "nixseparatedebuginfod";
        mode = "0755";
      }];
    };
}
