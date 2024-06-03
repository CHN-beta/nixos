inputs:
{
  config.home-manager.users.chn.config.programs.plasma.configFile =
    let
      nixos-wallpaper = inputs.pkgs.fetchgit
      {
        url = "https://git.chn.moe/chn/nixos-wallpaper.git";
        rev = "1ad78b20b21c9f4f7ba5f4c897f74276763317eb";
        sha256 = "0faahbzsr44bjmwr6508wi5hg59dfb57fzh5x6jh7zwmv4pzhqlb";
        fetchLFS = true;
      };
      wallpaper =
      {
        pc = "${nixos-wallpaper}/pixiv-117612023.png";
        surface = "${nixos-wallpaper}/misskey.io-9rr96ml6nti300ds-x4.png";
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
      # kdeglobals.General.accentColorFromWallpaper.value = true;
    };
}
