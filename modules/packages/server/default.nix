inputs:
{
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
            sshfs e2fsprogs adb-sync duperemove compsize
            # disk management
            smartmontools hdparm
            # encryption and authentication
            apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f yubico-piv-tool
            # networking
            ipset iptables iproute2 dig nettools traceroute tcping-go whois tcpdump nmap inetutils
            # nix tools
            nix-output-monitor nix-tree ssh-to-age
            # office
            todo-txt-cli
            # development
            gdb try inputs.topInputs.plasma-manager.packages.x86_64-linux.rc2nix
          ] ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ]);
          _pythonPackages = [(pythonPackages: with pythonPackages;
          [
            inquirerpy requests python-telegram-bot tqdm fastapi pypdf2 pandas matplotlib plotly gunicorn redis jinja2
            certifi charset-normalizer idna orjson psycopg2 localPackages.eigengdb
          ])];
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
        yazi.enable = true;
        mosh.enable = true;
      };
      services =
      {
        fwupd.enable = true;
        udev.packages = with inputs.pkgs; [ yubikey-personalization libfido2 ];
        openssh.knownHosts =
          let
            servers =
            {
              vps6 =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO5ZcvyRyOnUCuRtqrM/Qf+AdUe3a5bhbnfyhw2FSLDZ";
                hostnames = [ "internal.vps6.chn.moe" "vps6.chn.moe" "74.211.99.69" "192.168.82.1" ];
              };
              "initrd.vps6" =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4DKB/zzUYco5ap6k9+UxeO04LL12eGvkmQstnYxgnS";
                hostnames = [ "initrd.vps6.chn.moe" "74.211.99.69" ];
              };
              vps7 =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF5XkdilejDAlg5hZZD0oq69k8fQpe9hIJylTo/aLRgY";
                hostnames = [ "internal.vps7.chn.moe" "vps7.chn.moe" "95.111.228.40" "192.168.82.2" ];
              };
              "initrd.vps7" =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZyQpdQmEZw3nLERFmk2tS1gpSvXwW0Eish9UfhrRxC";
                hostnames = [ "initrd.vps7.chn.moe" "95.111.228.40" ];
              };
              nas =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIktNbEcDMKlibXg54u7QOLt0755qB/P4vfjwca8xY6V";
                hostnames = [ "internal.nas.chn.moe" "[office.chn.moe]:5440" "192.168.82.4" "192.168.1.185" ];
              };
              "initrd.nas" =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAoMu0HEaFQsnlJL0L6isnkNZdRq0OiDXyaX3+fl3NjT";
                hostnames = [ "[office.chn.moe]:5440" "192.168.1.185" ];
              };
              pc =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSfREi19OSwQnhdsE8wiNwGSFFJwNGN0M5gN+sdrrLJ";
                hostnames = [ "internal.pc.chn.moe" "192.168.8.2.3" ];
              };
              hpc =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVpsQW3kZt5alHC6mZhay3ZEe2fRGziG4YJWCv2nn/O";
                hostnames = [ "hpc.xmu.edu.cn" ];
              };
              github =
              {
                ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
                hostnames = [ "github.com" ];
              };
            };
          in listToAttrs (concatLists (map
            (server:
            (
              if builtins.pathExists ./ssh/${server.name}_rsa.pub then
              [{
                name = "${server.name}-rsa";
                value =
                {
                  publicKey = builtins.readFile ./ssh/${server.name}_rsa.pub;
                  hostNames = server.value.hostnames;
                };
              }]
              else []
            )
            ++ (
              if builtins.pathExists ./ssh/${server.name}_ecdsa.pub then
              [{
                name = "${server.name}-ecdsa";
                value =
                {
                  publicKey = builtins.readFile ./ssh/${server.name}_ecdsa.pub;
                  hostNames = server.value.hostnames;
                };
              }]
              else []
            )
            ++ (
              if server.value ? ed25519 then
              [{
                name = "${server.name}-ed25519";
                value =
                {
                  publicKey = server.value.ed25519;
                  hostNames = server.value.hostnames;
                };
              }]
              else []
            ))
            (attrsToList servers)));
      };
      home-manager = { useGlobalPkgs = true; useUserPackages = true; };
    };
}
