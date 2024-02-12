inputs:
{
  config = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  {
    home-manager.users.chn.config.home.file =
      let
        programs =
        {
          nheko =
            let
              drv = inputs.pkgs.writeTextDir "nheko.desktop" (builtins.replaceStrings
                [ "Exec=nheko %u" ] [ "Exec=bash -c 'sleep 5 && nheko'" ]
                (builtins.readFile "${inputs.pkgs.nheko}/share/applications/nheko.desktop"));
            in "${drv}/nheko.desktop";
          kclockd = "${inputs.pkgs.plasma5Packages.kdeGear.kclock}/etc/xdg/autostart/org.kde.kclockd-autostart.desktop";
          yakuake = "${inputs.pkgs.yakuake}/share/applications/org.kde.yakuake.desktop";
          telegram =
            let
              drv = inputs.pkgs.writeTextDir "org.telegram.desktop.desktop" (builtins.replaceStrings
                [ "Exec=telegram-desktop -- %u" ] [ "Exec=bash -c 'sleep 5 && telegram-desktop -autostart'" ]
                (builtins.readFile "${inputs.pkgs.telegram-desktop}/share/applications/org.telegram.desktop.desktop"));
            in "${drv}/org.telegram.desktop.desktop";
          element =
            let
              drv = inputs.pkgs.writeTextDir "element-desktop.desktop" (builtins.replaceStrings
                [ "Exec=element-desktop %u" ] [ "Exec=element-desktop --hidden" ]
                (builtins.readFile
                  "${inputs.pkgs.element-desktop.desktopItem}/share/applications/element-desktop.desktop"));
            in "${drv}/element-desktop.desktop";
          # kmail = 
          #   let
          #     drv = inputs.pkgs.writeTextDir "org.kde.kmail2.desktop" (builtins.replaceStrings
          #       [ "Exec=kmail -qwindowtitle %c %u" ] [ "Exec=bash -c 'sleep 5 && kmail -qwindowtitle'" ]
          #       (builtins.readFile "${inputs.pkgs.kmail}/share/applications/org.kde.kmail2.desktop"));
          #   in "${drv}/org.kde.kmail2.desktop";
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
          name = ".config/autostart/${builtins.baseNameOf (builtins.unsafeDiscardStringContext programs.${file})}";
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
