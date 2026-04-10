{ lib, config, pkgs, ... }:
{
  options.nixos.packages.vim = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) vim; in lib.mkIf (vim != null)
  {
    nixos.user.sharedModules =
    [{
      config.programs.vim =
      {
        enable = true;
        defaultEditor = false;
        packageConfigurable = config.programs.vim.package;
        settings =
        {
          number = true;
          expandtab = false;
          shiftwidth = 2;
          tabstop = 2;
        };
        extraConfig =
        ''
          set clipboard=unnamedplus
          colorscheme evening
        '';
      };
    }];
    programs.vim.package = pkgs.vim-full;
  };
}
