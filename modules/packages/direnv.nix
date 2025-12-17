inputs:
{
  options.nixos.packages.direnv = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default =
      if (inputs.config.nixos.model.type == "desktop") && (inputs.config.nixos.model.arch == "x86_64") then {}
      else null;
  };
  config = let inherit (inputs.config.nixos.packages) direnv; in inputs.lib.mkIf (direnv != null)
  {
    programs.direnv = { enable = true; nix-direnv.enable = true; };
    nixos.user.sharedModules = [{ config.programs.direnv.enable = true; }];
  };
}
