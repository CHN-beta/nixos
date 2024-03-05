inputs:
{
  options.nixos.system.binfmt = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = true; };
  };
  config = inputs.lib.mkIf inputs.config.nixos.system.binfmt.enable
  {
    programs.java = { enable = true; binfmt = true; };
    boot.binfmt.emulatedSystems = [ "aarch64-linux" "x86_64-windows" ];
  };
}
