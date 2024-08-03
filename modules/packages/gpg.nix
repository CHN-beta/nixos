inputs:
{
  options.nixos.packages.gpg = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) gpg; in inputs.lib.mkIf (gpg != null)
  {
    programs.gnupg.agent.enable = true;
  };
}
