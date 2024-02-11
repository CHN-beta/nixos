inputs:
{
  config.home-manager.users.chn.config.programs.plasma.configFile =
    let wallpaper = ./pixiv-96734339-x2.png; in
    {
      "plasma-org.kde.plasma.desktop-appletsrc" =
      {
        "Containments.1".wallpaperplugin = "a2n.blur";
        "Containments.1.Wallpaper.a2n.blur.General".Image = "file://${wallpaper}";
      };
      kscreenlockerrc."Greeter.Wallpaper.org.kde.image.General" = rec
        { Image = builtins.toString wallpaper; PreviewImage = Image; };
    };
}
