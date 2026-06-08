inputs: {
  config = {
    catppuccin = {
      flavor = "latte";
      tty.enable = true;
      autoEnable = false;
    };
    nixos.user.sharedModules = [
      {
        config = {
          catppuccin = {
            btop.enable = true;
            bat.enable = true;
            autoEnable = false;
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
