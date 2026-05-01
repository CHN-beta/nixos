{ lib, config, pkgs, ... }:
{
  options.nixos.services.github-runners =
    lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) github-runners; in lib.mkIf (github-runners != null)
  {
    services.github-runners.ufo =
    {
      enable = true;
      url = "https://github.com/CHN-beta";
      tokenFile = config.nixos.system.sops.secrets."github-runners/pat".path;
      extraPackages = with pkgs; [ nix git bash  ];
    };
    nixos.system.sops.secrets."github-runners/pat" = {};
  };
}
