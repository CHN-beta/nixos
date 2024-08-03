inputs:
{
  options.nixos.packages.vim = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) vim; in inputs.lib.mkIf (vim != null)
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
