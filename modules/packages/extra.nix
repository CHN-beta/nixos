inputs:
{
  options.nixos.packages.extra = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.packages) extra; in inputs.lib.mkIf (extra != null)
  {
    programs =
    {
      anime-game-launcher = { enable = true; package = inputs.pkgs.anime-game-launcher; };
      honkers-railway-launcher = { enable = true; package = inputs.pkgs.honkers-railway-launcher; };
      sleepy-launcher = { enable = true; package = inputs.pkgs.sleepy-launcher; };
    };
  };
}
