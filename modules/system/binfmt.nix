inputs:
{
  options.nixos.system.binfmt = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.system) binfmt; in inputs.lib.mkIf (binfmt != null)
  {
    programs.java = { enable = true; binfmt = true; };
    boot.binfmt.emulatedSystems = [ "aarch64-linux" "x86_64-windows" ];
  };
}
