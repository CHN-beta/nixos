inputs:
{
  config = inputs.lib.mkIf (builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ])
  {
    home-manager.users.chn.config.home.file =
      let
        programs =
        {
          nheko = rec
          {
            fileName = "nheko.desktop";
            path = "${inputs.pkgs.nheko}/share/applications/${fileName}";
          };
          kclockd = rec
          {
            fileName = "org.kde.kclockd-autostart.desktop";
            path = "${inputs.pkgs.kdePackages.kdeGear.kclock}/etc/xdg/autostart/${fileName}";
          };
          yakuake = rec
          {
            fileName = "org.kde.yakuake.desktop";
            path = "${inputs.pkgs.yakuake}/share/applications/${fileName}";
          };
          telegram = rec
          {
            fileName = "org.telegram.desktop.desktop";
            path = inputs.pkgs.writeText fileName (builtins.replaceStrings
                [ "Exec=telegram-desktop -- %u" ] [ "Exec=telegram-desktop -autostart" ]
                (builtins.readFile "${inputs.pkgs.telegram-desktop}/share/applications/${fileName}"));
          };
          element = rec
          {
            fileName = "element-desktop.desktop";
            path = inputs.pkgs.writeText fileName (builtins.replaceStrings
                [ "Exec=element-desktop %u" ] [ "Exec=element-desktop --hidden" ]
                (builtins.readFile "${inputs.pkgs.element-desktop.desktopItem}/share/applications/${fileName}"));
          };
          kmail = rec
          {
            fileName = "org.kde.kmail2.desktop";
            path = "${inputs.pkgs.kmail}/share/applications/${fileName}";
          };
          discord = rec
          {
            fileName = "discord.desktop";
            path = inputs.pkgs.writeText fileName (builtins.replaceStrings
                [ "Exec=Discord" ] [ "Exec=Discord --start-minimized" ]
                (builtins.readFile "${inputs.pkgs.discord.desktopItem}/share/applications/${fileName}"));
          };
          crow-translate = rec
          {
            fileName = "io.crow_translate.CrowTranslate.desktop";
            path = "${inputs.pkgs.crow-translate}/share/applications/${fileName}";
          };
        };
        devices =
        {
          pc = [ "nheko" "kclockd" "yakuake" "telegram" "element" "kmail" "discord" "crow-translate" ];
          surface = [ "kclockd" "yakuake" "telegram" "element" "crow-translate" ];
        };
      in builtins.listToAttrs (builtins.map
        (file:
        {
          name = ".config/autostart/${programs.${file}.fileName}";
          value.source = programs.${file}.path;
        })
        (devices.${inputs.config.nixos.model.hostname} or []));
    environment.persistence."/nix/rootfs/current".users.chn.directories =
      inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null != "worker") [ ".config/autostart" ];
  };
}
