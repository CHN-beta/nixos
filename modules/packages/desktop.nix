inputs:
{
  options.nixos.packages.desktop = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ] then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) desktop; in inputs.lib.mkIf (desktop != null)
  {
    nixos =
    {
      packages.packages =
      {
        _packages = with inputs.pkgs;
        [
          # system management
          # TODO: module should add yubikey-touch-detector into path
          gparted wayland-utils clinfo glxinfo vulkan-tools dracut yubikey-touch-detector btrfs-assistant snapper-gui
          kdePackages.qtstyleplugin-kvantum ventoy-full cpu-x wl-mirror geekbench xpra
          (
            writeShellScriptBin "xclip"
            ''
              if [ "$XDG_SESSION_TYPE" = "x11" ]; then exec ${xclip}/bin/xclip -sel clip "$@"
              else exec ${wl-clipboard-x11}/bin/xclip "$@"; fi
            ''
          )
          # color management
          argyllcms xcalib
          # networking
          remmina putty mtr-gui
          # media
          mpv nomacs simplescreenrecorder imagemagick gimp-with-plugins netease-cloud-music-gtk qcm
          waifu2x-converter-cpp blender paraview vlc whalebird spotify obs-studio
          (inkscape-with-extensions.override { inkscapeExtensions = null; })
          # themes
          klassy-qt6 localPackages.slate localPackages.blurred-wallpaper tela-circle-icon-theme
          catppuccin catppuccin-sddm catppuccin-cursors catppuccinifier-gui catppuccinifier-cli catppuccin-plymouth
          (catppuccin-kde.override { flavour = [ "latte" ]; }) (catppuccin-kvantum.override { variant = "latte"; })
          # terminal
          warp-terminal
          # development
          adb-sync scrcpy dbeaver-bin cling aircrack-ng
          weston cage openbox krita fprettify # jetbrains.clion 
          # desktop sharing
          rustdesk-flutter
          # password and key management
          yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui bitwarden hashcat
          electrum jabref john crunch
          # download
          qbittorrent nur-xddxdd.baidupcs-go wgetpaste onedrive onedrivegui rclone
          # editor
          typora appflowy notion-app-enhanced joplin-desktop standardnotes logseq obsidian code-cursor
          # news
          fluent-reader rssguard newsflash newsboat follow
          # nix tools
          nixpkgs-fmt appimage-run nixd nix-serve node2nix nix-prefetch-github prefetch-npm-deps nix-prefetch-docker
          nix-template nil bundix
          # instant messager
          element-desktop telegram-desktop discord zoom-us slack nur-linyinfeng.wemeet nheko
          fluffychat signal-desktop qq nur-xddxdd.wechat-uos-sandboxed cinny-desktop
          # browser
          google-chrome tor-browser microsoft-edge
          # office
          crow-translate zotero pandoc texliveFull poppler_utils pdftk pdfchain davinci-resolve
          ydict texstudio panoply pspp libreoffice-qt6-fresh ocrmypdf typst # paperwork
          # required by ltex-plus.vscode-ltex-plus
          ltex-ls ltex-ls-plus
          # matplot++ needs old gnuplot
          inputs.pkgs.pkgs-2311.gnuplot
          # math, physics and chemistry
          octaveFull ovito localPackages.vesta localPackages.v-sim jmol mpi geogebra6 localPackages.ufo
          (quantum-espresso.override { stdenv = gcc14Stdenv; gfortran = gfortran14;
            wannier90 = inputs.pkgs.wannier90.overrideAttrs { buildFlags = [ "dynlib" ]; }; })
          inputs.pkgs.pkgs-2311.hdfview numbat qalculate-qt
          # virtualization
          virt-viewer bottles wineWowPackages.stagingFull genymotion playonlinux
          # media
          nur-xddxdd.svp
          # for kdenlive auto subtitle
          openai-whisper
        ]
          ++ (builtins.filter (p: !((p.meta.broken or false) || (builtins.elem p.pname or null [ "falkon" "kalzium" ])))
            (builtins.filter inputs.lib.isDerivation (builtins.attrValues kdePackages.kdeGear)));
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          phonopy scipy scikit-learn jupyterlab autograd inputs.pkgs.localPackages.phono3py
          tensorflow keras numpy 
        ])];
      };
      user.sharedModules =
      [{
        config.programs =
        {
          plasma =
          {
            enable = true;
            configFile =
            {
              plasma-localerc = { Formats.LANG.value = "en_US.UTF-8"; Translations.LANGUAGE.value = "zh_CN"; };
              baloofilerc."Basic Settings".Indexing-Enabled.value = false;
              plasmarc.Wallpapers.usersWallpapers.value =
                let
                  inherit (inputs.topInputs) nixos-wallpaper;
                  isPicture = f: builtins.elem (inputs.lib.last (inputs.lib.splitString "." f))
                    [ "png" "jpg" "jpeg" "webp" ];
                in builtins.concatStringsSep "," (builtins.map (f: "${nixos-wallpaper}/${f.name}")
                  (builtins.filter (f: (isPicture f.name) && (f.value == "regular"))
                    (inputs.localLib.attrsToList (builtins.readDir nixos-wallpaper))));
            };
            powerdevil =
              let config =
              {
                autoSuspend.action = "nothing";
                dimDisplay.enable = false;
                powerButtonAction = "turnOffScreen";
                turnOffDisplay.idleTimeout = "never";
                whenLaptopLidClosed = "turnOffScreen";
              };
              in { AC = config; battery = config; lowBattery = config; };
          };
          obs-studio =
          {
            enable = true;
            plugins = with inputs.pkgs.obs-studio-plugins; [ wlrobs obs-vaapi droidcam-obs obs-vkcapture ];
          };
        };
      }];
    };
    programs =
    {
      adb.enable = true;
      wireshark = { enable = true; package = inputs.pkgs.wireshark; };
      yubikey-touch-detector.enable = true;
      kdeconnect.enable = true;
    };
    services.pcscd.enable = true;
  };
}
