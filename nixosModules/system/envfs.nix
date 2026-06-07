inputs: {
  options.nixos.system.envfs =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (types.submodule { });
      default =
        if
          builtins.elem inputs.config.nixos.model.variant [
            "desktop"
            "server"
          ]
        then
          { }
        else
          null;
    };
  config =
    let
      inherit (inputs.config.nixos.system) envfs;
    in
    inputs.lib.mkIf (envfs != null) {
      services.envfs.enable = true;
      environment.variables.ENVFS_RESOLVE_ALWAYS = "1";
    };
}
