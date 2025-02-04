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
    };
  };
}
