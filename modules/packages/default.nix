inputs:
{
  options.nixos.packages = let inherit (inputs.lib) mkOption types; in
  {
    packages = mkOption { default = []; type = types.listOf (types.enum
    [
      # games
      "genshin-impact" "honkers-starrail" "steam"
      # emulators
      "wine"
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
    (
      mkIf (builtins.elem "steam" inputs.config.nixos.packages.packages)
        { programs.steam.enable = true; }
    )
    (
      mkIf (builtins.elem "wine" inputs.config.nixos.packages.packages)
        { environment.systemPackages = [ inputs.pkgs.wine ]; }
    )
  ];
}
