inputs:
{
  options.nixos.packages.desktop = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.type == "desktop" then {} else null;
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
          gparted wayland-utils clinfo mesa-demos vulkan-tools dracut yubikey-touch-detector btrfs-assistant snapper-gui
          kdePackages.qtstyleplugin-kvantum cpu-x wl-mirror geekbench xpra
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
          mpv nomacs simplescreenrecorder imagemagick gimp-with-plugins netease-cloud-music-gtk # qcm
          waifu2x-converter-cpp blender paraview vlc whalebird spotify obs-studio subtitlecomposer
          (inkscape-with-extensions.override { inkscapeExtensions = [ inkscape-extensions.textext ]; })
          # development
          adb-sync scrcpy dbeaver-bin cling aircrack-ng kitty
          weston cage openbox krita fprettify # jetbrains.clion 
          # password and key management
          yubikey-manager bitwarden-desktop hashcat yubikey-personalization
          # download
          qbittorrent
          # editor
          typora standardnotes
          # news
          fluent-reader rssguard newsflash newsboat folo
          # nix tools
          nixpkgs-fmt appimage-run nixd nix-serve node2nix nix-prefetch-github prefetch-npm-deps nix-prefetch-docker
          nix-template nil bundix
          # instant messager
          element-desktop telegram-desktop discord zoom-us slack nheko
          # browser
          google-chrome tor-browser
          # office
          crow-translate zotero pandoc texliveFull poppler-utils pdftk pdfchain
          ydict texstudio panoply pspp libreoffice-qt6-still ocrmypdf typst # paperwork
          # required by ltex-plus.vscode-ltex-plus
          ltex-ls ltex-ls-plus
          # matplot++ needs old gnuplot
          pkgs-2311.gnuplot
          # math, physics and chemistry
          octaveFull ovito localPackages.vesta localPackages.v-sim jmol mpi geogebra6 localPackages.ufo
          (quantum-espresso.override { stdenv = gcc14Stdenv; gfortran = gfortran14; })
          pkgs-2311.hdfview numbat qalculate-qt
          # virtualization
          virt-viewer bottles wineWowPackages.stagingFull genymotion playonlinux
          # media
          nur-xddxdd.svp
          # for kdenlive auto subtitle
          openai-whisper
          # daily management
          activitywatch super-productivity
        ]
          ++ (builtins.filter
            (p: (inputs.lib.isDerivation p) && !(p.meta.broken or false)
              && !(builtins.elem p.pname or null [ "falkon" "kalzium" "calligra" "kamoso" ]))
            (builtins.attrValues kdePackages.kdeGear))
          ++ (inputs.lib.optionals (inputs.config.nixos.system.gui.implementation == "kde")
            [ inputs.topInputs.plasma-manager.packages.${inputs.pkgs.system}.rc2nix ]);
        _pythonPackages = [(pythonPackages: with pythonPackages;
          [ phonopy scipy scikit-learn jupyterlab autograd inputs.pkgs.localPackages.phono3py numpy ])];
      };
      user.sharedModules =
      [{
        config.programs =
        {
          plasma = inputs.lib.mkIf (inputs.config.nixos.system.gui.implementation == "kde")
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
                  listDirRecursive =
                    let listDir = dir:
                      if dir.value == "directory" then builtins.concatLists
                        (builtins.map (f: listDir f) (inputs.localLib.attrsToList (builtins.readDir dir.name)))
                      else [ dir ];
                    in dir: listDir { name = dir; value = "directory"; };
                in builtins.concatStringsSep "," (builtins.map (f: "${nixos-wallpaper}/${f.name}")
                  (builtins.filter (f: (isPicture f.name) && (f.value == "regular"))
                    (listDirRecursive nixos-wallpaper)));
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
      kde-pim.enable = false;
      alvr = { enable = true; openFirewall = true; };
      localsend.enable = true;
      thunderbird.enable = true;
      nh.enable = true;
    };
    services = { pcscd.enable = true; lact.enable = true; };
  };
}
