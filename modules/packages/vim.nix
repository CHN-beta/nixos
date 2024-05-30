inputs:
{
  config = inputs.lib.mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
  {
    nixos.user.sharedModules =
    [{
      config.programs.vim =
      {
        enable = true;
        defaultEditor = true;
        packageConfigurable = inputs.config.programs.vim.package;
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
    programs.vim.package = inputs.pkgs.vim-full;
  };
}
