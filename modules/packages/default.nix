inputs:
{
  options.nixos.packages = let inherit (inputs.lib) mkOption types; in
  {
    packages = mkOption { default = []; type = types.listOf (types.enum
    [
      # games
      "genshin-impact" "honkers-star-rail"
    ]); };
  };
  config =
  {
    programs = {}
    // (
      if builtins.elem "genshin-impact" inputs.config.nixos.packages.packages
        then { anime-game-launcher.enable = true; }
        else {}
    )
    // (
      if builtins.elem "honkers-star-rail" inputs.config.nixos.packages.packages
        then { honkers-railway-launcher.enable = true; }
        else {}
    );
  };
}
