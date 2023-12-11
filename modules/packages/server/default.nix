inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./ssh
  ];
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
            pciutils usbutils lshw util-linux lsof
            # top
            iotop iftop htop btop powertop s-tui
            # editor
            nano bat
            # downloader
            wget aria2 curl yt-dlp
            # file manager
            tree eza trash-cli lsd broot file xdg-ninja mlocate
            # compress
            pigz rar upx unzip zip lzip p7zip
            # file system management
            sshfs e2fsprogs adb-sync duperemove compsize exfatprogs
            # disk management
            smartmontools hdparm
            # encryption and authentication
            apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f yubico-piv-tool
            # networking
            ipset iptables iproute2 dig nettools traceroute tcping-go whois tcpdump nmap inetutils wireguard-tools
            # nix tools
            nix-output-monitor nix-tree ssh-to-age
            # office
            todo-txt-cli
            # development
            gdb try inputs.topInputs.plasma-manager.packages.x86_64-linux.rc2nix
          ] ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ]);
        };
        users.sharedModules = [(home-inputs:
        {
          config.programs =
          {
            zsh =
            {
              enable = true;
              initExtraBeforeCompInit =
              ''
                # p10k instant prompt
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
                path = "${home-inputs.config.xdg.dataHome}/zsh/zsh_history";
                extended = true;
                save = 100000000;
                size = 100000000;
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
