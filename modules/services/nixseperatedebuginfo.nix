inputs:
{
  options.nixos.services.nixseparatedebuginfo = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ] then {} else null;
  };
  config =
    let inherit (inputs.config.nixos.services) nixseparatedebuginfo; in inputs.lib.mkIf (nixseparatedebuginfo != {})
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
