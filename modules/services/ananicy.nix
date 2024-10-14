inputs:
{
  options.nixos.services.ananicy = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) ananicy; in inputs.lib.mkIf (ananicy != null)
  {
    services.ananicy =
    {
      enable = true;
      package = inputs.pkgs.ananicy-cpp;
      rulesProvider = inputs.pkgs.ananicy-rules-cachyos;
    };
  };
}
