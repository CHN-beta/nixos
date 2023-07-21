inputs:
{
  options.nixos.packages = let inherit (inputs.lib) mkOption types; in
  {
    packages = mkOption { default = []; type = types.listOf (types.enum
    [
      # games
      "genshin-impact" "honkers-starrail"
    ]); };
  };
  config = let inherit (inputs.lib) mkMerge mkIf; in mkMerge
  [
    (
      mkIf (builtins.elem "genshin-impact" inputs.config.nixos.packages.packages)
        { programs.anime-game-launcher.enable = true; }
    )
    (
      mkIf (builtins.elem "honkers-starrail" inputs.config.nixos.packages.packages)
        { programs.honkers-railway-launcher.enable = true; }
    )
  ];
}
