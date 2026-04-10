{ lib, config, ... }:
{
  options.nixos.packages.gpg = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) gpg; in lib.mkIf (gpg != null)
  {
    programs.gnupg.agent.enable = true;
  };
}
