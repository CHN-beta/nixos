inputs:
{
  options.nixos.packages = let inherit (inputs.lib) mkOption types; in
  {
    packages = mkOption { default = []; type = types.listOf (types.enum
    [
      "basic" "games" "wine" "gui-extra" "office" "vscode"
    ]); };
  };
  config = let inherit (inputs.lib) mkMerge mkIf; in mkMerge
  [
    (
      mkIf (builtins.elem "basic" inputs.config.nixos.packages.packages)
      {
        environment.systemPackages = with inputs.pkgs;
        [
          # shell
          ksh
          # basic tools
          beep dos2unix gnugrep pv tmux
          # lsxx
          pciutils usbutils lshw wayland-utils clinfo glxinfo vulkan-tools util-linux
          # top
          iotop iftop htop
          # editor
          vim nano
          # downloader
          wget aria2 curl yt-dlp
          # file manager
          tree git autojump exa trash-cli lsd zellij broot file
          # compress
          pigz rar upx unzip zip lzip p7zip
          # file system management
          sshfs e2fsprogs adb-sync
          # disk management
          smartmontools
          # encryption and authentication
          apacheHttpd openssl ssh-to-age gnupg age sops
          # networking
          ipset iptables iproute2 dig nettools
          # nix tools
          nix-output-monitor nix-template appimage-run nil nixd nix-alien
          # development
          gcc go rustc

          # move to other place
          kio-fuse pam_u2f tldr
          pdfchain wgetpaste httplib clang magic-enum xtensor
          boost cereal cxxopts valgrind
          todo-txt-cli pandoc
        ];
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
          command-not-found.enable = false;
          adb.enable = true;
          gnupg.agent = { enable = true; enableSSHSupport = true; };
        };
        services =
        {
          fwupd.enable = true;
          udev.packages = [ inputs.pkgs.yubikey-personalization ];
        };
      }
    )
    (
      mkIf (builtins.elem "games" inputs.config.nixos.packages.packages) { programs =
      {
        anime-game-launcher.enable = true;
        honkers-railway-launcher.enable = true;
        steam.enable = true;
      };}
    )
    (
      mkIf (builtins.elem "wine" inputs.config.nixos.packages.packages)
        { environment.systemPackages = [ inputs.pkgs.wine ]; }
    )
    (
      mkIf (builtins.elem "gui-extra" inputs.config.nixos.packages.packages)
        { environment.systemPackages = with inputs.pkgs; [ qbittorrent element-desktop tdesktop discord ]; }
    )
    (
      mkIf (builtins.elem "office" inputs.config.nixos.packages.packages)
        { environment.systemPackages = with inputs.pkgs; [ libreoffice-qt ]; }
    )
    (
      mkIf (builtins.elem "vscode" inputs.config.nixos.packages.packages)
      {
        environment.systemPackages = [(inputs.pkgs.vscode-with-extensions.override
        {
          vscodeExtensions = with inputs.pkgs.nix-vscode-extensions.vscode-marketplace;
            (with equinusocio; [ vsc-community-material-theme vsc-material-theme vsc-material-theme-icons ])
            ++ (with github; [ copilot github-vscode-theme ])
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
              jeff-hykin.better-cpp-syntax josetr.cmake-language-support-vscode fredericbonnet.cmake-test-adapter
              hirse.vscode-ungit fortran-lang.linter-gfortran
            ];
        })];
      }
    )
  ];
}
