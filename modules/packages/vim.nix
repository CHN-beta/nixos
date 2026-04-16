{ config, pkgs, ... }:
{
  config =
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
