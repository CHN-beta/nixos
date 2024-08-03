inputs:
{
  options.nixos.system.nix-ld = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.system) nix-ld; in inputs.lib.mkIf (nix-ld != null)
  {
    programs.nix-ld = { enable = true; libraries = [ inputs.pkgs.steam-run.fhsenv ]; };
  };
}
