inputs:
{
  config.home-manager.users.chn.config.programs.plasma.configFile =
    let
      inherit (inputs.topInputs) nixos-wallpaper;
      wallpaper =
      {
        pc = "${nixos-wallpaper}/pixiv-117612023.png";
        surface = "${nixos-wallpaper}/fanbox-6682738.png";
      }.${inputs.config.nixos.system.networking.hostname} or "${nixos-wallpaper}/pixiv-96734339-x2.png";
    in
    {
      # "plasma-org.kde.plasma.desktop-appletsrc" =
      # {
      #   "Containments/1".wallpaperplugin.value = "a2n.blur";
      #   "Containments/1/Wallpaper/a2n.blur/General".Image.value = wallpaper;
      # };
      kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General" =
        { Image.value = wallpaper; PreviewImage.value = wallpaper; };
      kdeglobals.General.accentColorFromWallpaper.value = true;
    };
}
