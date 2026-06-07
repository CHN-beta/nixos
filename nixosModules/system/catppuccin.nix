inputs: {
  config = {
    catppuccin.flavor = "latte";
    catppuccin.tty.enable = true;
    nixos.user.sharedModules = [
      {
        config = {
          catppuccin = {
            btop.enable = true;
            bat.enable = true;
          };
          programs = {
            bat.enable = true;
            btop.enable = true;
          };
          xdg = {
            enable = true;
            configFile."btop/btop.conf".force = true;
          };
        };
      }
    ];
  };
}
