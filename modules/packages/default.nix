inputs:
{
  options.nixos.packages = let inherit (inputs.lib) mkOption types; in
  {
    packageSet = mkOption
    {
      type = types.enum
      [
        # no gui, only used for specific purpose
        "server"
        # gui, for daily use, but not install large programs such as matlab
        "desktop"
        # nearly everything
        "workstation"
      ];
      default = "server";
    };
    extraPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    excludePackages = mkOption { type = types.listOf types.unspecified; default = []; };
    extraPythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    excludePythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    extraPrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    excludePrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    _packages = mkOption { type = types.listOf types.unspecified; default = []; };
    _pythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
    _prebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
  };
  config = let inherit (inputs.lib) mkMerge mkIf; inherit (inputs.localLib) stripeTabs; in mkMerge
  [
    # >= server
    {
      nixos =
      {
        packages = with inputs.pkgs;
        {
          _packages = 
          [
            # shell
            ksh
            # basic tools
            beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq zellij neofetch ipfetch
            # lsxx
            pciutils usbutils lshw util-linux lsof
            # top
            iotop iftop htop btop powertop s-tui
            # editor
            nano bat
            # downloader
            wget aria2 curl
            # file manager
            tree exa trash-cli lsd broot file xdg-ninja mlocate
            # compress
            pigz rar upx unzip zip lzip p7zip
            # file system management
            sshfs e2fsprogs adb-sync duperemove compsize
            # disk management
            smartmontools hdparm
            # encryption and authentication
            apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f yubico-piv-tool
            # networking
            ipset iptables iproute2 dig nettools traceroute tcping-go whois tcpdump nmap inetutils
            # nix tools
            nix-output-monitor nix-tree
            # office
            todo-txt-cli
            # development
            gdb
          ] ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ]);
          _pythonPackages = [(pythonPackages: with pythonPackages;
          [
            inquirerpy requests python-telegram-bot tqdm fastapi pypdf2 pandas matplotlib plotly gunicorn redis jinja2
            certifi charset-normalizer idna orjson psycopg2
          ])];
        };
        users.sharedModules =
        [{
          config.programs =
          {
            zsh =
            {
              enable = true;
              initExtraBeforeCompInit =
              ''
                # p10k instant prompt
                typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
                P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
                [[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"
                HYPHEN_INSENSITIVE="true"
                export PATH=~/bin:$PATH
                function br
                {
                  local cmd cmd_file code
                  cmd_file=$(mktemp)
                  if broot --outcmd "$cmd_file" "$@"; then
                    cmd=$(<"$cmd_file")
                    command rm -f "$cmd_file"
                    eval "$cmd"
                  else
                    code=$?
                    command rm -f "$cmd_file"
                    return "$code"
                  fi
                }
                alias todo="todo.sh"
              '';
              plugins =
              [
                {
                  file = "powerlevel10k.zsh-theme";
                  name = "powerlevel10k";
                  src = "${inputs.pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
                }
                {
                  file = "p10k.zsh";
                  name = "powerlevel10k-config";
                  src = ./p10k-config;
                }
                {
                  name = "zsh-lsd";
                  src = inputs.pkgs.fetchFromGitHub
                  {
                    owner = "z-shell";
                    repo = "zsh-lsd";
                    rev = "029a9cb0a9b39c9eb6c5b5100dd9182813332250";
                    sha256 = "sha256-oWjWnhiimlGBMaZlZB+OM47jd9hporKlPNwCx6524Rk=";
                  };
                }
              ];
              history =
              {
                extended = true;
                save = 100000000;
                size = 100000000;
                share = true;
              };
            };
            direnv = { enable = true; nix-direnv.enable = true; };
            git =
            {
              enable = true;
              lfs.enable = true;
              extraConfig =
              {
                core.editor = if inputs.config.nixos.system.gui.preferred then "code --wait" else "vim";
                advice.detachedHead = false;
                merge.conflictstyle = "diff3";
                diff.colorMoved = "default";
              };
              package = inputs.pkgs.gitFull;
              delta =
              {
                enable = true;
                options =
                {
                  side-by-side = true;
                  navigate = true;
                  syntax-theme = "GitHub";
                  light = true;
                  zero-style = "syntax white";
                  line-numbers-zero-style = "#ffffff";
                };
              };
            };
            ssh =
            {
              enable = true;
              controlMaster = "auto";
              controlPersist = "1m";
              compression = true;
            };
            vim =
            {
              enable = true;
              defaultEditor = true;
              packageConfigurable = inputs.config.programs.vim.package;
              settings =
              {
                number = true;
                expandtab = false;
                shiftwidth = 2;
                tabstop = 2;
              };
              extraConfig =
              ''
                set clipboard=unnamedplus
                colorscheme evening
              '';
            };
          };
        }];
      };
      programs =
      {
        nix-index-database.comma.enable = true;
        nix-index.enable = true;
        zsh =
        {
          enable = true;
          syntaxHighlighting.enable = true;
          autosuggestions.enable = true;
          enableCompletion = true;
          ohMyZsh =
          {
            enable = true;
            plugins = [ "git" "colored-man-pages" "extract" "history-substring-search" "autojump" ];
            customPkgs = with inputs.pkgs; [ zsh-nix-shell ];
          };
        };
        ccache.enable = true;
        command-not-found.enable = false;
        adb.enable = true;
        gnupg.agent = { enable = true; enableSSHSupport = true; };
        autojump.enable = true;
        git =
        {
          enable = true;
          package = inputs.pkgs.gitFull;
          lfs.enable = true;
          config =
          {
            init.defaultBranch = "main";
            core = { quotepath = false; editor = "vim"; };
          };
        };
      };
      services =
      {
        fwupd.enable = true;
        udev.packages = with inputs.pkgs; [ yubikey-personalization libfido2 ];
      };
      nix.settings.extra-sandbox-paths = [ inputs.config.programs.ccache.cacheDir ];
      nixpkgs.config =
      {
        permittedInsecurePackages = with inputs.pkgs;
        [
          openssl_1_1.name electron_19.name nodejs-16_x.name python2.name electron_12.name
        ];
        allowUnfree = true;
      };
      home-manager =
      {
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    }
    # >= desktop
    (
      mkIf (builtins.elem inputs.config.nixos.packages.packageSet [ "desktop" "workstation" ] )
      {
        nixos =
        {
          packages = with inputs.pkgs;
          {
            _packages =
            [
              # system management
              gparted snapper-gui libsForQt5.qtstyleplugin-kvantum wl-clipboard-x11 kio-fuse wl-mirror
              wayland-utils clinfo glxinfo vulkan-tools dracut etcher
              # nix tools
              ssh-to-age deploy-rs.deploy-rs nixpkgs-fmt
              # instant messager
              element-desktop telegram-desktop discord inputs.config.nur.repos.linyinfeng.wemeet # native
              cinny-desktop # nur-xddxdd.wine-wechat thunder
              # browser
              google-chrome
              # networking
              remmina putty mtr-gui
              # password and key management
              bitwarden yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui
              # download
              qbittorrent yt-dlp nur-xddxdd.baidupcs-go wgetpaste
              # office
              unstablePackages.crow-translate zotero pandoc
              # development
              scrcpy
              # media
              spotify yesplaymusic mpv nomacs simplescreenrecorder imagemagick gimp netease-cloud-music-gtk vlc
              # text editor
              localPackages.typora
              # themes
              orchis-theme tela-circle-icon-theme plasma-overdose-kde-theme materia-kde-theme graphite-kde-theme
              arc-kde-theme materia-theme
              # news
              fluent-reader rssguard
              # davinci-resolve playonlinux
              weston cage openbox krita
              genymotion hdfview
              (
                vscode-with-extensions.override
                {
                  vscodeExtensions = with nix-vscode-extensions.vscode-marketplace;
                    (with equinusocio; [ vsc-community-material-theme vsc-material-theme-icons ])
                    ++ (with github; [ copilot copilot-chat copilot-labs github-vscode-theme ])
                    ++ (with intellsmi; [ comment-translate deepl-translate ])
                    ++ (with ms-python; [ isort python vscode-pylance ])
                    ++ (with ms-toolsai;
                    [
                      jupyter jupyter-keymap jupyter-renderers vscode-jupyter-cell-tags vscode-jupyter-slideshow
                    ])
                    ++ (with ms-vscode;
                    [
                      cmake-tools cpptools cpptools-extension-pack cpptools-themes hexeditor remote-explorer
                      test-adapter-converter
                    ])
                    ++ (with ms-vscode-remote; [ remote-ssh remote-containers remote-ssh-edit ])
                    ++ [
                      donjayamanne.githistory genieai.chatgpt-vscode fabiospampinato.vscode-diff cschlosser.doxdocgen
                      llvm-vs-code-extensions.vscode-clangd ms-ceintl.vscode-language-pack-zh-hans oderwat.indent-rainbow
                      twxs.cmake guyutongxue.cpp-reference znck.grammarly thfriedrich.lammps leetcode.vscode-leetcode
                      james-yu.latex-workshop gimly81.matlab affenwiesel.matlab-formatter ckolkman.vscode-postgres
                      yzhang.markdown-all-in-one pkief.material-icon-theme bbenoist.nix ms-ossdata.vscode-postgresql
                      redhat.vscode-xml dotjoshjohnson.xml jnoortheen.nix-ide xdebug.php-debug hbenl.vscode-test-explorer
                      jeff-hykin.better-cpp-syntax fredericbonnet.cmake-test-adapter mesonbuild.mesonbuild
                      hirse.vscode-ungit fortran-lang.linter-gfortran tboox.xmake-vscode ccls-project.ccls
                      feiskyer.chatgpt-copilot yukiuuh2936.vscode-modern-fortran-formatter wolframresearch.wolfram
                      njpipeorgan.wolfram-language-notebook brettm12345.nixfmt-vscode
                    ];
                }
              )
            ] ++ (with inputs.lib; filter isDerivation (attrValues plasma5Packages.kdeGear));
          };
          users.sharedModules =
          [{
            config =
            {
              programs =
              {
                chromium =
                {
                  enable = true;
                  extensions =
                  [
                    { id = "mpkodccbngfoacfalldjimigbofkhgjn"; } # Aria2 Explorer
                    { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
                    { id = "kbfnbcaeplbcioakkpcpgfkobkghlhen"; } # Grammarly
                    { id = "ihnfpdchjnmlehnoeffgcbakfmdjcckn"; } # Pixiv Fanbox Downloader
                    { id = "cimiefiiaegbelhefglklhhakcgmhkai"; } # Plasma Integration
                    { id = "dkndmhgdcmjdmkdonmbgjpijejdcilfh"; } # Powerful Pixiv Downloader
                    { id = "padekgcemlokbadohgkifijomclgjgif"; } # Proxy SwitchyOmega
                    { id = "kefjpfngnndepjbopdmoebkipbgkggaa"; } # RSSHub Radar
                    { id = "abpdnfjocnmdomablahdcfnoggeeiedb"; } # Save All Resources
                    { id = "nbokbjkabcmbfdlbddjidfmibcpneigj"; } # SmoothScroll
                    { id = "onepmapfbjohnegdmfhndpefjkppbjkm"; } # SuperCopy 超级复制
                    { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
                    { id = "gppongmhjkpfnbhagpmjfkannfbllamg"; } # Wappalyzer
                    { id = "hkbdddpiemdeibjoknnofflfgbgnebcm"; } # YouTube™ 双字幕
                    { id = "ekhagklcjbdpajgpjgmbionohlpdbjgc"; } # Zotero Connector
                    { id = "ikhdkkncnoglghljlkmcimlnlhkeamad"; } # 划词翻译
                    { id = "dhdgffkkebhmkfjojejmpbldmpobfkfo"; } # 篡改猴
                    { id = "hipekcciheckooncpjeljhnekcoolahp"; } # Tabliss
                  ];
                };
                obs-studio =
                {
                  enable = true;
                  plugins = with inputs.pkgs.obs-studio-plugins;
                    [ wlrobs obs-vaapi obs-nvfbc droidcam-obs obs-vkcapture ];
                };
              };
              home.file.".config/baloofilerc".text =
              ''
                [Basic Settings]
                Indexing-Enabled=false
              '';
            };
          }];
        };
        programs =
        {
          steam.enable = true;
          kdeconnect.enable = true;
          wireshark = { enable = true; package = inputs.pkgs.wireshark; };
          firefox =
          {
            enable = true;
            languagePacks = [ "zh-CN" "en-US" ];
            nativeMessagingHosts.firefoxpwa = true;
          };
          vim.package = inputs.pkgs.genericPackages.vim-full;
        };
        nixpkgs.config.packageOverrides = pkgs: 
        {
          telegram-desktop = pkgs.telegram-desktop.overrideAttrs (attrs:
          {
            patches = (if (attrs ? patches) then attrs.patches else []) ++ [ ./telegram.patch ];
          });
        };
        services.pcscd.enable = true;
      }
    )
    # >= workstation
    (
      mkIf (inputs.config.nixos.packages.packageSet == "workstation")
      {
        nixos.packages = with inputs.pkgs;
        {
          _packages =
          [
            # nix tools
            nix-template appimage-run nil nixd nix-alien nix-serve node2nix nix-prefetch-github prefetch-npm-deps
            nix-prefetch-docker pnpm-lock-export bundix
            # instant messager
            zoom-us signal-desktop qq nur-xddxdd.wechat-uos slack # jail
            # office
            libreoffice-qt texlive.combined.scheme-full texstudio poppler_utils pdftk gnuplot pdfchain
            # development
            jetbrains.clion android-studio dbeaver cling clang-tools_16 ccls fprettify
            # media
            nur-xddxdd.svp obs-studio waifu2x-converter-cpp inkscape blender
            # virtualization
            wineWowPackages.stagingFull virt-viewer bottles # wine64
            # text editor
            appflowy notion-app-enhanced joplin-desktop standardnotes
            # math, physics and chemistry
            mathematica octave root ovito paraview localPackages.vesta qchem.quantum-espresso
            localPackages.vasp localPackages.phonon-unfolding localPackages.vaspkit jmol localPackages.v_sim
            # news
            newsflash newsboat
          ];
          _pythonPackages = [(pythonPackages: with pythonPackages;
          [
            phonopy tensorflow keras openai scipy scikit-learn
          ])];
          _prebuildPackages =
          [
            httplib magic-enum xtensor boost cereal cxxopts ftxui yaml-cpp gfortran gcc10 python2 gcc13Stdenv
          ];
        };
        programs =
        {
          anime-game-launcher.enable = true;
          honkers-railway-launcher.enable = true;
          nix-ld.enable = true;
          gamemode =
          {
            enable = true;
            settings =
            {
              general.renice = 10;
              gpu =
              {
                apply_gpu_optimisations = "accept-responsibility";
                nv_powermizer_mode = 1;
              };
              custom = let notify-send = "${inputs.pkgs.libnotify}/bin/notify-send"; in
              {
                start = "${notify-send} 'GameMode started'";
                end = "${notify-send} 'GameMode ended'";
              };
            };
          };
          chromium =
          {
            enable = true;
            extraOpts =
            {
              PasswordManagerEnabled = false;
            };
          };
        };
      }
    )
    # apply package configs
    {
      environment.systemPackages = let inherit (inputs.lib.lists) subtractLists; in with inputs.config.nixos.packages;
        (subtractLists excludePackages (_packages ++ extraPackages))
        ++ [
          (inputs.pkgs.python3.withPackages (pythonPackages:
            subtractLists
              (builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
                excludePythonPackages))
              (builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
                (_pythonPackages ++ extraPythonPackages)))))
          (inputs.pkgs.callPackage ({ stdenv }: stdenv.mkDerivation
          {
            name = "prebuild-packages";
            propagateBuildInputs = subtractLists excludePrebuildPackages (_prebuildPackages ++ extraPrebuildPackages);
            phases = [ "installPhase" ];
            installPhase = stripeTabs
            ''
              runHook preInstall
              mkdir -p $out
              runHook postInstall
            '';
          }) {})
        ];
    }
  ];
}

    # programs.firejail =
    # {
    #   enable = true;
    #   wrappedBinaries =
    #   {
    #     qq =
    #     {
    #       executable = "${inputs.pkgs.qq}/bin/qq";
    #       profile = "${inputs.pkgs.firejail}/etc/firejail/linuxqq.profile";
    #     };
    #   };
    # };

# config.nixpkgs.config.replaceStdenv = { pkgs }: pkgs.ccacheStdenv;
  # only replace stdenv for large and tested packages
  # config.programs.ccache.packageNames = [ "webkitgtk" "libreoffice" "tensorflow" "linux" "chromium" ];
  # config.nixpkgs.overlays = [(final: prev:
  # {
  #   libreoffice-qt = prev.libreoffice-qt.override (prev: { unwrapped = prev.unwrapped.override
  #     (prev: { stdenv = final.ccacheStdenv.override { stdenv = prev.stdenv; }; }); });
  #   python3 = prev.python3.override { packageOverrides = python-final: python-prev:
  #     {
  #       tensorflow = python-prev.tensorflow.override
  #         { stdenv = final.ccacheStdenv.override { stdenv = python-prev.tensorflow.stdenv; }; };
  #     };};
  #   # webkitgtk = prev.webkitgtk.override (prev:
  #   #   { stdenv = final.ccacheStdenv.override { stdenv = prev.stdenv; }; enableUnifiedBuilds = false; });
  #   wxGTK31 = prev.wxGTK31.override { stdenv = final.ccacheStdenv.override { stdenv = prev.wxGTK31.stdenv; }; };
  #   wxGTK32 = prev.wxGTK32.override { stdenv = final.ccacheStdenv.override { stdenv = prev.wxGTK32.stdenv; }; };
  #   # firefox-unwrapped = prev.firefox-unwrapped.override
  #   #   { stdenv = final.ccacheStdenv.override { stdenv = prev.firefox-unwrapped.stdenv; }; };
  #   # chromium = prev.chromium.override
  #   #   { stdenv = final.ccacheStdenv.override { stdenv = prev.chromium.stdenv; }; };
  #   # linuxPackages_xanmod_latest = prev.linuxPackages_xanmod_latest.override
  #   # {
  #   #   kernel = prev.linuxPackages_xanmod_latest.kernel.override
  #   #   {
  #   #     stdenv = final.ccacheStdenv.override { stdenv = prev.linuxPackages_xanmod_latest.kernel.stdenv; };
  #   #     buildPackages = prev.linuxPackages_xanmod_latest.kernel.buildPackages //
  #   #       { stdenv = prev.linuxPackages_xanmod_latest.kernel.buildPackages.stdenv; };
  #   #   };
  #   # };
  # })];
  # config.programs.ccache.packageNames = [ "libreoffice-unwrapped" ];

# cross-x86_64-pc-linux-musl/gcc
# dev-cpp/cpp-httplib ? how to use
# dev-cpp/cppcoro
# dev-cpp/date
# dev-cpp/nameof
# dev-cpp/scnlib
# dev-cpp/tgbot-cpp
# dev-libs/pocketfft
# dev-util/intel-hpckit
# dev-util/nvhpc
# kde-misc/wallpaper-engine-kde-plugin
# media-fonts/arphicfonts
# media-fonts/sarasa-gothic
# media-gfx/flameshot
# media-libs/libva-intel-driver
# media-libs/libva-intel-media-driver
# media-sound/netease-cloud-music
# net-vpn/frp
# net-wireless/bluez-tools
# sci-libs/mkl
# sci-libs/openblas
# sci-libs/pfft
# sci-libs/scalapack
# sci-libs/wannier90
# sci-mathematics/ginac
# sci-mathematics/mathematica
# sci-mathematics/octave
# sci-physics/lammps::touchfish-os
# sci-physics/vsim
# sci-visualization/scidavis
# sys-apps/flatpak
# sys-cluster/modules
# sys-devel/distcc
# sys-fs/btrfs-progs
# sys-fs/compsize
# sys-fs/dosfstools
# sys-fs/duperemove
# sys-fs/exfatprogs
# sys-fs/mdadm
# sys-fs/ntfs3g
# sys-kernel/dracut
# sys-kernel/linux-firmware
# sys-kernel/xanmod-sources
# sys-kernel/xanmod-sources:6.1.12
# sys-kernel/xanmod-sources::touchfish-os
# sys-libs/libbacktrace
# sys-libs/libselinux
# x11-apps/xinput
# x11-base/xorg-apps
# x11-base/xorg-fonts
# x11-base/xorg-server
# x11-misc/imwheel
# x11-misc/optimus-manager
# x11-misc/unclutter-xfixes

#   ++ ( with inputs.pkgs.pkgsCross.mingwW64.buildPackages; [ gcc ] );