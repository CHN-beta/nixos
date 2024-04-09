inputs:
{
  config.home-manager.users.chn.config.programs.plasma.configFile =
    let wallpaper =
    {
      pc = ./pixiv-117612023.png;
      surface = ./misskey.io-9rr96ml6nti300ds-x4.png;
    }.${inputs.config.nixos.system.networking.hostname} or ./pixiv-96734339-x2.png;
    in
    {
      "plasma-org.kde.plasma.desktop-appletsrc" =
      {
        "Containments.1".wallpaperplugin = "a2n.blur";
        "Containments.1.Wallpaper.a2n\\.blur.General".Image = "${wallpaper}";
      };
      kscreenlockerrc."Greeter.Wallpaper.org\\.kde\\.image.General" =
        { Image = "${wallpaper}"; PreviewImage = "${wallpaper}"; };
      kdeglobals.General.accentColorFromWallpaper = true;
    };
}
