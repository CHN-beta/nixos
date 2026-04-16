{ lib, config, pkgs, ... }:
{
  options.nixos.packages.zellij = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) zellij; in lib.mkIf (zellij != null)
  {
    environment.systemPackages = [ pkgs.zellij ];
    nixos.user.sharedModules =
    [{
      config.programs.zellij =
      {
        enable = true;
        settings = { scroll_buffer_size = 100000000; show_startup_tips = false; show_release_notes = false; };
      };
    }];
  };
}
