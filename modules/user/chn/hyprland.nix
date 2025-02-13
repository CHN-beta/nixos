inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.packages.desktop != null)
  {
    home-manager.users.chn.config =
    {
      programs.hyprlock =
      {
        enable = true;
        settings =
        {
          general = { disable_loading_bar = true; hide_cursor = true; };
          background.path = "${inputs.topInputs.nixos-wallpaper}/twitter-1884592003595592025.jpg";
          input-field =
          [{
            # as least one entry is required even it is default
            position = "0, 0";
            # size = "200, 50";
            # position = "0, -80";
            # font_color = "rgb(202, 211, 245)";
            # inner_color = "rgb(91, 96, 120)";
            # outer_color = "rgb(24, 25, 38)";
            # outline_thickness = 5;
            # placeholder_text = '\'<span foreground="##cad3f5">Password...</span>'\';
            # shadow_passes = 2;
          }];
        };
      };
      wayland.windowManager.hyprland =
      {
        enable = true;
        settings =
        {
        };
        extraConfig = builtins.readFile ./hyprland.conf;
        systemd.enable = false;
        xwayland.enable = true;
      };
      services.hyprpaper =
      {
        enable = true;
        settings =
        {
          preload = [ "${inputs.topInputs.nixos-wallpaper}/twitter-1884592003595592025.jpg" ];
          wallpaper = [ ",${inputs.topInputs.nixos-wallpaper}/twitter-1884592003595592025.jpg" ];
        };
      };
    };
  };
}
