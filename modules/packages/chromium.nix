{ lib, config, ... }:
{
  options.nixos.packages.chromium = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule {});
    default = if config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (config.nixos.packages) chromium; in lib.mkIf (chromium != null)
  {
    programs.chromium = { enable = true; extraOpts.PasswordManagerEnabled = false; };
  };
}
