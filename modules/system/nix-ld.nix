inputs:
{
  options.nixos.system.nix-ld = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.system) nix-ld; in inputs.lib.mkIf (nix-ld != null)
  {
    programs.nix-ld = { enable = true; libraries = [ inputs.pkgs.steam-run.fhsenv ]; };
  };
}
