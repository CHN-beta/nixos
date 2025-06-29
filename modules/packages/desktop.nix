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
          gparted yubikey-touch-detector btrfs-assistant kdePackages.qtstyleplugin-kvantum cpu-x wl-mirror xpra
          (
            writeShellScriptBin "xclip"
            ''
              if [ "$XDG_SESSION_TYPE" = "x11" ]; then exec ${xclip}/bin/xclip -sel clip "$@"
              else exec ${wl-clipboard-x11}/bin/xclip "$@"; fi
            ''
          )
          # networking
          remmina putty kdePackages.krdc
          # media
          mpv nomacs simplescreenrecorder imagemagick gimp-with-plugins qcm waifu2x-converter-cpp blender paraview vlc
          obs-studio (inkscape-with-extensions.override { inkscapeExtensions = null; }) kdePackages.kcolorchooser
          kdePackages.kdenlive
          # development
          adb-sync scrcpy dbeaver-bin aircrack-ng fprettify waveterm
          # password and key management
          yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui bitwarden hashcat
          kdePackages.kleopatra
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
          element-desktop telegram-desktop discord zoom-us slack nheko nur-linyinfeng.wemeet
          # browser
          google-chrome tor-browser
          # office
          crow-translate zotero pandoc texliveFull poppler_utils pdftk pdfchain activitywatch
          ydict pspp libreoffice-qt6-fresh ocrmypdf typst kdePackages.kruler
          # required by ltex-plus.vscode-ltex-plus
          ltex-ls ltex-ls-plus
          # matplot++ needs old gnuplot
          inputs.pkgs.pkgs-2311.gnuplot
          # math, physics and chemistry
          octaveFull mpi geogebra6 qalculate-qt
          # virtualization
          bottles wineWowPackages.stagingFull
          # media
          nur-xddxdd.svp
          # for kdenlive auto subtitle
          openai-whisper
        ];
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          scipy scikit-learn jupyterlab autograd numpy 
        ])];
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
      kdeconnect.enable = inputs.lib.mkIf (inputs.config.nixos.system.gui.implementation == "kde") true;
      kde-pim = inputs.lib.mkIf (inputs.config.nixos.system.gui.implementation == "kde")
        { enable = true; kmail = true; };
      coolercontrol =
        { enable = true; nvidiaSupport = inputs.lib.hasSuffix "nvidia" inputs.config.nixos.hardware.gpu.type; };
      anime-game-launcher = { enable = true; package = inputs.pkgs.anime-game-launcher; };
      honkers-railway-launcher = { enable = true; package = inputs.pkgs.honkers-railway-launcher; };
      sleepy-launcher = { enable = true; package = inputs.pkgs.sleepy-launcher; };
    };
    services = { pcscd.enable = true; lact.enable = true; };
  };
}
