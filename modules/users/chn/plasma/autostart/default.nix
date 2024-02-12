inputs:
{
  config = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  {
    home-manager.users.chn.config.home.file =
      let
        programs =
        {
          nheko = "${inputs.pkgs.nheko}/share/applications/nheko.desktop";
          kclockd = "${inputs.pkgs.plasma5Packages.kdeGear.kclock}/etc/xdg/autostart/org.kde.kclockd-autostart.desktop";
          yakuake = "${inputs.pkgs.yakuake}/share/applications/org.kde.yakuake.desktop";
          telegram = ./org.telegram.desktop.desktop;
          element =
            let
              drv = inputs.pkgs.writeTextDir "element-desktop.desktop" (builtins.replaceStrings
                [ "Exec=element-desktop %u" ] [ "Exec=element-desktop --hide" ]
                (builtins.readFile "${inputs.pkgs.element-desktop.desktopItem}/share/applications/element-desktop.desktop"));
            in "${drv}/element-desktop.desktop";
          kmail = "${inputs.pkgs.kmail}/share/applications/org.kde.kmail2.desktop";
          discord =
            let
              drv = inputs.pkgs.writeTextDir "discord.desktop" (builtins.replaceStrings
                [ "Exec=Discord" ] [ "Exec=Discord --start-minimized" ]
                (builtins.readFile "${inputs.pkgs.discord.desktopItem}/share/applications/discord.desktop"));
            in "${drv}/discord.desktop";
        };
        devices =
        {
          pc = [ "nheko" "kclockd" "yakuake" "telegram" "element" "kmail" "discord" ];
          surface = [ "kclockd" "yakuake" "telegram" "element" ];
        };
      in builtins.listToAttrs (builtins.map
        (file:
        {
          name = ".config/autostart/${builtins.baseNameOf "programs.${file}"}";
          value.source = programs.${file};
        })
        (devices.${inputs.config.nixos.system.networking.hostname}));
    environment.persistence =
      let impermanence = inputs.config.nixos.system.impermanence;
      in inputs.lib.mkIf impermanence.enable
      {
        "${impermanence.root}".users.chn.directories = [ ".config/autostart" ];
      };
  };
}
