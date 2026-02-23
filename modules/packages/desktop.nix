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
          gparted wayland-utils clinfo mesa-demos vulkan-tools dracut yubikey-touch-detector btrfs-assistant
          cpu-x wl-mirror geekbench xpra
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
          nomacs simplescreenrecorder imagemagick gimp-with-plugins netease-cloud-music-gtk splayer go-musicfox
          waifu2x-converter-cpp blender vlc whalebird spotify obs-studio subtitlecomposer
          (inkscape-with-extensions.override { inkscapeExtensions = [ inkscape-extensions.textext ]; })
          (paraview.overrideAttrs (prev: { nativeBuildInputs = prev.nativeBuildInputs
            ++ [(python3.withPackages (ps: with ps; [ numpy matplotlib ]))]; }))
          # development
          adb-sync scrcpy dbeaver-bin cling aircrack-ng opencode
          weston cage openbox krita fprettify # jetbrains.clion 
          # password and key management
          yubikey-manager bitwarden-desktop hashcat yubikey-personalization
          # download
          qbittorrent
          # editor
          typora standardnotes obsidian
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
          crow-translate zotero pandoc texliveFull poppler-utils pdftk pdfchain kdePackages.kruler kdePackages.okular
          ydict texstudio panoply pspp libreoffice-fresh ocrmypdf typst # paperwork
          # required by ltex-plus.vscode-ltex-plus
          ltex-ls ltex-ls-plus
          # matplot++ needs old gnuplot
          pkgs-2311.gnuplot
          # math, physics and chemistry
          octaveFull ovito localPackages.vesta localPackages.v-sim mpi geogebra6 localPackages.ufo
          (quantum-espresso.override { stdenv = gcc14Stdenv; gfortran = gfortran14; })
          pkgs-2311.hdfview
          # media
          nur-xddxdd.svp
          # for kdenlive auto subtitle
          openai-whisper
          # daily management
          super-productivity
          # gaming
          (bottles.override { removeWanningPopup = true; })
          # AI
          alpaca
        ];
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          scipy scikit-learn jupyterlab autograd inputs.pkgs.localPackages.phono3py numpy
          openai python-telegram-bot fastapi-cli pypdf2 pandas matplotlib plotly gunicorn redis jinja2 certifi 
          charset-normalizer idna orjson psycopg2 inquirerpy requests tqdm pydbus inputs.pkgs.localPackages.brokenaxes
          # allow pandas read odf
          odfpy
        ])];
      };
      user.sharedModules =
      [{
        config =
        {
          # TODO: use nixos module, enable kernel module
          programs.obs-studio =
          {
            enable = true;
            plugins = with inputs.pkgs.obs-studio-plugins; [ wlrobs obs-vaapi droidcam-obs obs-vkcapture ];
          };
          xdg.configFile."typora-flags.conf".text =
            "--ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3";
        };
      }];
    };
    programs =
    {
      adb.enable = true;
      wireshark = { enable = true; package = inputs.pkgs.wireshark; };
      yubikey-touch-detector.enable = true;
      kdeconnect.enable = true;
      alvr = { enable = true; openFirewall = true; };
      localsend.enable = true;
      thunderbird.enable = true;
      nh.enable = true;
    };
    services.pcscd.enable = true;
  };
}
