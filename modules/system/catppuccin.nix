inputs:
{
  config =
  {
    catppuccin.flavour = "latte";
    console.catppuccin.enable = true;
    boot.loader.grub.catppuccin.enable = true;
    nixos.user.sharedModules =
    [{
      config =
      {
        programs =
        {
          bat = { enable = true; catppuccin.enable = true; };
          btop = { enable = true; catppuccin.enable = true; };
        };
        xdg = { enable = true; configFile."btop/btop.conf".force = true; };
      };
    }];
  };
}
