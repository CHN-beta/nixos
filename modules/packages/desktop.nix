{ lib, pkgs, config, ... }:
{
  options.nixos.packages.desktop = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule {});
    default = if config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (config.nixos.packages) desktop; in lib.mkIf (desktop != null)
  {
    nixos =
    {
      packages.packages._packages = with pkgs;
      [
        # system management
        # TODO: module should add yubikey-touch-detector into path
        gparted wayland-utils clinfo mesa-demos vulkan-tools dracut
        yubikey-touch-detector btrfs-assistant
        cpu-x wl-mirror geekbench xpra wl-clipboard xsel libinput
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
        nomacs simplescreenrecorder imagemagick gimp-with-plugins
        netease-cloud-music-gtk splayer go-musicfox
        waifu2x-converter-cpp blender vlc whalebird spotify obs-studio
        subtitlecomposer
        (inkscape-with-extensions.override { inkscapeExtensions = [ inkscape-extensions.textext ]; })
        (paraview.overrideAttrs (prev: { nativeBuildInputs = prev.nativeBuildInputs
          ++ [(python3.withPackages (ps: with ps; [ numpy matplotlib ]))]; }))
        satty
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
        nixpkgs-fmt appimage-run nixd nix-serve node2nix nix-prefetch-github
        prefetch-npm-deps nix-prefetch-docker
        nix-template nil bundix
        # instant messager
        element-desktop telegram-desktop discord zoom-us slack nheko
        teamspeak3
        # browser
        google-chrome tor-browser
        # office
        crow-translate zotero pandoc texliveFull poppler-utils pdftk
        pdfchain kdePackages.kruler kdePackages.okular
        ydict texstudio panoply pspp libreoffice-fresh ocrmypdf typst
        rnote localPkgs.xinli # paperwork
        # required by ltex-plus.vscode-ltex-plus
        ltex-ls ltex-ls-plus
        # matplot++ needs old gnuplot
        pkgs-2311.gnuplot
        # math, physics and chemistry
        octaveFull ovito localPkgs.vesta localPkgs.v-sim mpi geogebra6
        localPkgs.ufo
        (quantum-espresso.override { stdenv = gcc14Stdenv; gfortran = gfortran14; })
        pkgs-2311.hdfview
        # media
        nur-xddxdd.svp
        # for kdenlive auto subtitle
        openai-whisper
        # daily management
        super-productivity pkgs-unstable.vikunja-desktop
        # gaming
        (bottles.override { removeWarningPopup = true; }) lutris
        # AI
        alpaca
      ];
      user.sharedModules =
      [{
        config =
        {
          # TODO: use nixos module, enable kernel module
          programs.obs-studio =
          {
            enable = true;
            plugins = with pkgs.obs-studio-plugins; [ wlrobs obs-vaapi droidcam-obs obs-vkcapture ];
          };
          xdg.configFile."typora-flags.conf".text =
          ''
            --ozone-platform-hint=auto
            --enable-features=WaylandWindowDecorations
            --enable-wayland-ime=true
            --wayland-text-input-version=3
          '';
        };
      }];
    };
    programs =
    {
      adb.enable = true;
      wireshark = { enable = true; package = pkgs.wireshark; };
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
