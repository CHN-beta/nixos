inputs:
{
  imports = inputs.localLib.findModules ./.;
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "chn" user.users)
  {
    users.users.chn =
    {
      extraGroups = inputs.lib.intersectLists
        [ "adbusers" "networkmanager" "wheel" "wireshark" "libvirtd" ]
        (builtins.attrNames inputs.config.users.groups);
      autoSubUidGidRange = true;
      hashedPassword = "$y$j9T$xJwVBoGENJEDSesJ0LfkU1$VEExaw7UZtFyB4VY1yirJvl7qS7oiF49KbEBrV0.hhC";
      openssh.authorizedKeys.keys = [(builtins.readFile ./id_ed25519_sk.pub)];
    };
    home-manager.users.chn =
    {
      config =
      {
        programs =
        {
          git = { userName = "chn"; userEmail = "chn@chn.moe"; };
          ssh =
          {
            matchBlocks =
            {
              # identityFile = "~/.ssh/xmuhk_id_rsa";
              xmuhk = { host = "xmuhk"; hostname = "10.26.14.56"; user = "xmuhk"; };
              xmuhk2 = { host = "xmuhk2"; hostname = "183.233.219.132"; user = "xmuhk"; port = 62022; };
            }
            // (builtins.listToAttrs (builtins.map
              (system: { name = system; value.forwardAgent = true; })
              [
                "vps6" "wireguard.vps6" "vps7" "wireguard.vps7" "wireguard.pc" "nas" "wireguard.nas" "pc"
                "wireguard.surface" "xmupc1" "wireguard.xmupc1" "xmupc2" "wireguard.xmupc2"
              ]));
            extraConfig =
              inputs.lib.mkIf (builtins.elem inputs.config.nixos.system.networking.hostname [ "pc" "surface" ])
              ''
                IdentityFile ~/.ssh/id_rsa
                IdentityFile ~/.ssh/id_ed25519_sk
              '';
          };
        };
        home =
        {
          file.groupshare.enable = false;
          packages =
          [
            (
              let
                servers = builtins.filter
                  (system: system.value.enable)
                  (builtins.map
                    (system:
                    {
                      name = system.config.nixos.system.networking.hostname;
                      value = system.config.nixos.system.fileSystems.decrypt.manual;
                    })
                    (builtins.attrValues inputs.topInputs.self.nixosConfigurations));
                cat = "${inputs.pkgs.coreutils}/bin/cat";
                gpg = "${inputs.pkgs.gnupg}/bin/gpg";
                ssh = "${inputs.pkgs.openssh}/bin/ssh";
              in inputs.pkgs.writeShellScriptBin "remote-decrypt" (builtins.concatStringsSep "\n"
                (
                  (builtins.map (system: builtins.concatStringsSep "\n"
                    [
                      "decrypt-${system.name}() {"
                      "  key=$(${cat} ${system.value.keyFile} | ${gpg} --decrypt)"
                      (builtins.concatStringsSep "\n" (builtins.map
                        (device: "  echo $key | ${ssh} root@initrd.${system.name}.chn.moe cryptsetup luksOpen "
                          + (if device.value.ssd then "--allow-discards " else "")
                          + "${device.name} ${device.value.mapper} -")
                        (inputs.localLib.attrsToList system.value.devices)))
                      "}"
                    ])
                    servers)
                  ++ [ "decrypt-$1" ]
                ))
            )
          ];
        };
        pam.yubico.authorizedYubiKeys.ids = [ "cccccbgrhnub" ];
      };
    };
    environment.persistence =
      let inherit (inputs.config.nixos.system) impermanence; in inputs.lib.mkIf impermanence.enable
      {
        "${impermanence.persistence}".users.chn =
        {
          directories = builtins.map
            (dir: { directory = dir.dir or dir; user = "chn"; group = "chn"; mode = dir.mode or "0755"; })
            [
              # common things
              "bin" "Desktop" "Documents" "Downloads" "Music" "Pictures" "repo" "share" "Public" "Videos"
              ".config" ".local/share"
              # # gnome
              # { dir = ".config/dconf"; mode = "0700"; } ".config/gtk-2.0" ".config/gtk-3.0" ".config/gtk-4.0"
              # ".config/libaccounts-glib"
              # # android
              # { dir = ".android"; mode = "0750";}
              # xmuvpn
              ".ecdata"
              # firefox
              { dir = ".mozilla/firefox/default"; mode = "0700"; }
              # ssh
              { dir = ".ssh"; mode = "0700"; }
              # steam
              ".steam" # ".local/share/Steam"
              # vscode
              ".vscode" # ".config/Code" ".config/grammarly-languageserver"
              # zotero
              ".zotero" "Zotero"
              # 百度网盘
              # ".config/BaiduPCS-Go"
              # # bitwarden
              # ".config/Bitwarden"
              # # blender
              # ".config/blender"
              # # chromium
              # ".config/chromium"
              # # crow-translate
              # ".config/crow-translate"
              # # discord
              # ".config/discord"
              # # element
              # ".config/Element"
              # # fcitx
              # ".config/fcitx5" ".local/share/fcitx5"
              # # github
              # ".config/gh"
              # # gimp
              # ".config/GIMP"
              # # chrome
              # ".config/google-chrome"
              # # inkscape
              # ".config/inkscape"
              # # jetbrain
              # ".config/JetBrains" ".local/share/JetBrains"
              # # kde
              # ".config/akonadi" ".config/KDE" ".config/kde.org" ".config/kdeconnect" ".config/kdedefaults"
              # ".config/Kvantum"
              # ".local/share/akonadi" ".local/share/akonadi-davgroupware"
              # ".local/share/kactivitymanagerd" ".local/share/kwalletd" ".local/share/plasma"
              # ".local/share/plasma-systemmonitor" ".local/share/plasma_notes"
              # # libreoffice
              # ".config/libreoffice"
              # # mathematica
              # ".config/mathematica"
              # # netease-cloud-music-gtk
              # ".config/netease-cloud-music" ".local/share/netease-cloud-music-gtk4"
              # # nheko
              # ".config/nheko" ".local/share/nheko"
              # # ovito
              # ".config/Ovito"
              # # qbittorrent
              # ".config/qBittorrent" ".local/share/qBittorrent"
              # # remmina
              # ".config/remmina" ".local/share/remmina"
              # # slack
              # ".config/Slack"
              # # spotify
              # ".config/spotify"
              # # systemd TODO: use declarative
              # ".config/systemd/user"
              # # typora
              # ".config/Typora"
              # # xsettingsd
              # ".config/xsettingsd"
              # # yesplaymusic
              # ".config/yesplaymusic"
              # # genshin
              # ".local/share/anime-game-launcher"
              # # applications
              # ".local/share/applications" ".local/share/desktop-directories"
              # # theme TODO: remove them
              # ".local/share/color-schemes" ".local/share/icons" ".local/share/wallpapers"
              # # dbeaver
              # ".local/share/DbeaverData"
              # # docker
              # ".local/share/docker"
              # # fonts TODO: use declarative
              # ".local/share/fonts"
              # # gpg
              # ".local/share/gnupg"
              # # TODO: what is this?
              # ".local/share/mime"
              # # telegram
              # ".local/share/TelegramDesktop"
              # # trash
              # ".local/share/Trash"
              # # waydroid
              # ".local/share/waydroid"
              # # zsh
              # ".local/share/zsh"
            ];
          # TODO: create file if not exist
          # files = builtins.map
          #   (file: { inherit file; parentDirectory = { user = "chn"; group = "chn"; mode = "0755"; }; })
          #   [
          #     # kde
          #     ".config/kactivitymanagerdrc" ".config/plasma-org.kde.plasma.desktop-appletsrc"
          #     ".config/kactivitymanagerd-switcher" ".config/kactivitymanagerd-statsrc"
          #     ".config/kactivitymanagerd-pluginsrc"
          #     ".config/plasmarc" ".config/plasmashellrc" ".config/kwinrc" ".config/krunnerrc"
          #     ".config/kdeglobals" ".config/kglobalshortcutsrc" ".config/kio_fishrc" ".config/kiorc"
          #     ".config/kleopatrarc" ".config/kmail2rc" ".config/kmailsearchindexingrc" ".config/kscreenlockerrc"
          #     ".config/user-dirs.dirs" ".config/yakuakerc"
          #     # age TODO: use sops to storage
          #     ".config/sops/age/keys.txt"
          #   ];
        };
      };
  };
}
