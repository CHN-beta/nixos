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
          gparted yubikey-touch-detector btrfs-assistant
          kdePackages.qtstyleplugin-kvantum cpu-x wl-mirror xpra
          (
            writeShellScriptBin "xclip"
            ''
              if [ "$XDG_SESSION_TYPE" = "x11" ]; then exec ${xclip}/bin/xclip -sel clip "$@"
              else exec ${wl-clipboard-x11}/bin/xclip "$@"; fi
            ''
          )
          # networking
          remmina putty
          # media
          mpv nomacs simplescreenrecorder imagemagick gimp-with-plugins qcm waifu2x-converter-cpp blender paraview vlc
          obs-studio (inkscape-with-extensions.override { inkscapeExtensions = null; })
          # themes
          klassy-qt6 localPackages.slate localPackages.blurred-wallpaper
          # development
          adb-sync scrcpy dbeaver-bin aircrack-ng fprettify
          # password and key management
          yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui bitwarden hashcat
          # download
          qbittorrent wgetpaste rclone
          # editor
          typora
          # news
          fluent-reader newsflash follow
          # nix tools
          nixpkgs-fmt nixd nix-serve nix-prefetch-github prefetch-npm-deps nix-prefetch-docker
          # required by vscode nix tools
          nil
          # instant messager
          element-desktop telegram-desktop discord zoom-us slack nheko
          # browser
          google-chrome tor-browser
          # office
          crow-translate zotero pandoc texliveFull poppler_utils pdftk pdfchain
          ydict pspp libreoffice-qt6-fresh ocrmypdf typst
          # required by ltex-plus.vscode-ltex-plus
          ltex-ls ltex-ls-plus
          # matplot++ needs old gnuplot
          inputs.pkgs.pkgs-2311.gnuplot
          # math, physics and chemistry
          octaveFull ovito localPackages.vesta localPackages.v-sim mpi geogebra6 localPackages.ufo
          inputs.pkgs.pkgs-2311.hdfview qalculate-qt
          # virtualization
          bottles wineWowPackages.stagingFull
          # media
          nur-xddxdd.svp
          # for kdenlive auto subtitle
          openai-whisper
        ]
          ++ (builtins.filter (p: !((p.meta.broken or false) || (builtins.elem p.pname or null [ "falkon" "kalzium" ])))
            (builtins.filter inputs.lib.isDerivation (builtins.attrValues kdePackages.kdeGear)));
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          phonopy scipy scikit-learn jupyterlab autograd inputs.pkgs.localPackages.phono3py numpy 
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
