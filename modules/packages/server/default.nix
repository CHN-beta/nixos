inputs:
{
  imports = inputs.localLib.findModules ./.;
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (builtins) concatLists map listToAttrs;
      inherit (inputs.localLib) attrsToList;
    in mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
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
            beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq zellij neofetch ipfetch localPackages.pslist
            fastfetch reptyr
            # lsxx
            pciutils usbutils lshw util-linux lsof dmidecode
            # top
            iotop iftop htop btop powertop s-tui
            # editor
            nano bat
            # downloader
            wget aria2 curl yt-dlp
            # file manager
            tree eza trash-cli lsd broot file xdg-ninja mlocate
            # compress
            pigz upx unzip zip lzip p7zip
            # file system management
            sshfs e2fsprogs duperemove compsize exfatprogs
            # disk management
            smartmontools hdparm
            # encryption and authentication
            apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f yubico-piv-tool
            # networking
            ipset iptables iproute2 dig nettools traceroute tcping-go whois tcpdump nmap inetutils wireguard-tools
            # nix tools
            nix-output-monitor nix-tree ssh-to-age (callPackage "${inputs.topInputs.nix-fast-build}" {})
            # office
            todo-txt-cli pdfgrep
            # development
            gdb try inputs.topInputs.plasma-manager.packages.${inputs.pkgs.system}.rc2nix hexo-cli gh stdenv gfortran
            nodejs
            # library
            fmt fmt.dev localPackages.nameof localPackages.matplotplusplus highfive hdf5 hdf5.dev
          ]
          ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ])
          ++ (inputs.lib.optional (inputs.config.nixos.system.nixpkgs.arch == "x86_64") rar);
          _pythonPackages = [(pythonPackages: with pythonPackages;
          [
            openai python-telegram-bot fastapi pypdf2 pandas matplotlib plotly gunicorn redis jinja2
            certifi charset-normalizer idna orjson psycopg2 inquirerpy requests tqdm pydbus
          ])];
        };
        user.sharedModules = [(home-inputs:
        {
          config.programs =
          {
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
        })];
      };
      programs =
      {
        nix-index-database.comma.enable = true;
        nix-index.enable = true;
        command-not-found.enable = false;
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
        yazi.enable = true;
        mosh.enable = true;
      };
      services =
      {
        fwupd.enable = true;
        udev.packages = with inputs.pkgs; [ yubikey-personalization libfido2 ];
      };
      home-manager = { useGlobalPkgs = true; useUserPackages = true; };
    };
}
