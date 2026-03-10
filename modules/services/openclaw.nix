{ config, lib, topInputs, ... }:
{
  options.nixos.services.openclaw = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) openclaw; in lib.mkIf (openclaw != null)
  {
    nixos =
    {
      user.users = [ "claw" ];
    };
    home-manager.users.claw =
    {
      imports = [ topInputs.nix-openclaw.homeManagerModules.openclaw ];
      config.programs.openclaw =
      {
        enable = true;
        bundledPlugins =
        {
          summarize.enable = true;   # Summarize web pages, PDFs, videos
          bird.enable = true;       # Twitter/X
        };
      };
    };
  };
}
