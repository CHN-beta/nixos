{ lib, config, pkgs, self, ... }:
{
  config = lib.mkMerge
  [
    {
      environment.systemPackages = with pkgs;
      [
        # basic tools
        beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq yq-go
        ipfetch localPkgs.pslist
        fastfetch reptyr duc ncdu progress libva-utils ksh
        dateutils glib cryptsetup i2c-tools trash-cli cpuid
        stress-ng
        (if pkgs.config.cudaSupport or false then gpu-burn else emptyDirectory)
        # lsxx
        pciutils usbutils lshw util-linux lsof dmidecode lm_sensors hwloc
        acpica-tools ethtool
        # top
        iotop iftop htop powertop s-tui
        # editor
        nano bat
        # downloader
        wget aria2 curl yt-dlp ffsend b4
        # file manager
        tree eza trash-cli lsd broot file xdg-ninja mlocate
        # compress
        pigz upx unzip zip lzip p7zip rpm
        (if pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then rar else emptyDirectory)
        # file system management
        sshfs e2fsprogs compsize exfatprogs
        # disk management
        smartmontools hdparm gptfdisk multipath-tools
        (if pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then megacli else emptyDirectory)
        # encryption and authentication
        apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f
        yubico-piv-tool libfido2 gnutls opensc
        # networking
        ipset iptables iproute2 dig nettools traceroute tcping-go whois
        tcpdump nmap inetutils wireguard-tools openvpn
        parted xray iw
        # nix tools
        nix-output-monitor nix-tree ssh-to-age nix-inspect
        # development
        gdb try rr hexo-cli gh hugo
        # build failed on aarch64
        (if pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then nix-init else emptyDirectory)
        (octodns.withProviders (_: with octodns-providers; [ cloudflare ]))
        # stupid things
        toilet dotacat localPkgs.stickerpicker graph-easy tokei
        # shell
        # somehow fish does not compile on aarch64
        (if config.nixos.model.arch == "x86_64" then kitty else emptyDirectory)
      ]
        ++ (with config.boot.kernelPackages; [ cpupower usbip ]);
      programs =
      {
        nix-index-database.comma.enable = true;
        nix-index.enable = true;
        command-not-found.enable = false;
        autojump.enable = true;
        mosh.enable = true;
        gnupg.agent.enable = true;
        nbd.enable = true;
      };
      services =
      {
        udev.packages = with pkgs; [ yubikey-personalization libfido2 ];
        fwupd =
        {
          enable = true;
          # allow fwupd install firmware from any source (e.g. manually extracted from msi)
          daemonSettings.OnlyTrusted = false;
        };
      };
      home-manager = { useGlobalPkgs = true; useUserPackages = true; };
      # allow everyone run compsize
      security.wrappers.compsize =
        { setuid = true; owner = "root"; group = "root"; source = "${pkgs.compsize}/bin/compsize"; };
    }
    {
      environment.systemPackages = [ pkgs.zellij ];
      nixos.user.sharedModules =
      [{
        config.programs.zellij =
        {
          enable = true;
          settings = { scroll_buffer_size = 100000000; show_startup_tips = false; show_release_notes = false; };
        };
      }];
    }
    {
      programs.yazi.enable = true;
      nixos.user.sharedModules =
      [{
        config.programs.yazi =
        {
          enable = true;
          shellWrapperName = "yy";
          keymap.mgr.append_keymap =
          [
            { on = "T"; run = "shell --orphan ghostty"; }
            { on = [ "c" "a" "a" ]; run = "plugin compress"; }
          ];
          plugins = { inherit (pkgs.yaziPlugins) compress; };
          settings.tasks.image_bound = [ 65535 65535 ];
        };
      }];
    }
    {
      nixos.user.sharedModules =
      [{
        config.programs.vim =
        {
          enable = true;
          defaultEditor = false;
          packageConfigurable = config.programs.vim.package;
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
      }];
      programs.vim.package = pkgs.vim-full;
    }
    {
      nixos.user.sharedModules =
        [{ config.programs.helix = { enable = true; defaultEditor = true; settings.theme = "catppuccin_latte"; }; }];
      environment.systemPackages = [ pkgs.helix ];
    }
    {
      environment.systemPackages = [ pkgs.nushell ];
      nixos.user.sharedModules =
      [{
        config.programs =
        {
          nushell =
          {
            enable = true;
            extraConfig =
            ''
              source ${self.inputs.nu-scripts}/aliases/git/git-aliases.nu
              $env.PATH = ($env.PATH | split row (char esep) | append "~/bin")
            '';
          };
          carapace.enable = true;
          oh-my-posh =
          {
            enable = true;
            enableZshIntegration = false;
            settings = lib.deepReplace
              [
                {
                  path = [ "blocks" 0 "segments" (v: v.type or "" == "path") "properties" "style" ];
                  value = "powerlevel";
                }
                {
                  path = [ "blocks" 0 "segments" (v: v.type or "" == "executiontime") "template" ];
                  value = v: builtins.replaceStrings [ "⠀" ] [ " " ] v;
                }
              ]
              (builtins.fromJSON (builtins.readFile
                "${pkgs.oh-my-posh}/share/oh-my-posh/themes/atomic.omp.json"));
          };
          zoxide.enable = true;
        };
      }];
    }
    {
      nixos.user.sharedModules =
      [{
        config.programs.ghostty =
        {
          enable = true;
          settings = { scrollback-limit = 100000000; keybind = "ctrl+shift+r=reset"; linux-cgroup = "always"; };
        };
      }];
      environment.systemPackages = [ pkgs.ghostty ];
    }
    {
      environment.systemPackages = [ pkgs.btop ];
      nixos.user.sharedModules =
        [{ config.programs.btop = { enable = true; settings.btrfs_group_subvolumes = true; }; }];
    }
    {
      nixos.user.sharedModules = [(home-inputs:
      {
        config = lib.mkMerge
        [
          {
            programs.zsh =
            {
              enable = true;
              dotDir = home-inputs.config.home.homeDirectory;
              history =
              {
                path = "${home-inputs.config.xdg.dataHome}/zsh/zsh_history";
                extended = true;
                save = 100000000;
                size = 100000000;
              };
              syntaxHighlighting.enable = true;
              autosuggestion.enable = true;
              enableCompletion = true;
              oh-my-zsh =
              {
                enable = true;
                plugins = [ "git" "colored-man-pages" "extract" "history-substring-search" "autojump" ];
                theme = lib.mkDefault "clean";
              };
              # ensure ~/.zlogin exists
              loginExtra = " ";
            };
            home.shell.enableZshIntegration = true;
          }
          {
            programs =
              let optional = lib.mkIf (builtins.elem home-inputs.config.home.username
                [ "chn" "root" "aleksana" "alikia" "hjp" "lilydjwg" "straycat" ]);
              in
              {
                zsh = optional
                {
                  plugins =
                  [
                    {
                      file = "powerlevel10k.zsh-theme";
                      name = "powerlevel10k";
                      src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
                    }
                    { file = "p10k.zsh"; name = "powerlevel10k-config"; src = ./p10k-config; }
                    {
                      name = "zsh-lsd";
                      src = pkgs.fetchFromGitHub
                      {
                        owner = "z-shell";
                        repo = "zsh-lsd";
                        rev = "65bb5ac49190beda263aae552a9369127961632d";
                        hash = "sha256-JSNsfpgiqWhtmGQkC3B0R1Y1QnDKp9n0Zaqzjhwt7Xk=";
                      };
                    }
                  ];
                  initContent = lib.mkOrder 550
                  ''
                    # p10k instant prompt
                    P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
                    [[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"
                    HYPHEN_INSENSITIVE="true"
                    export PATH=~/bin:$PATH
                    zstyle ':vcs_info:*' disable-patterns "/nix/remote/*"
                  '';
                  oh-my-zsh.theme = "";
                };
                fzf = optional { enable = true; };
              };
          }
        ];
      })];
      environment.pathsToLink = [ "/share/zsh" ];
      programs.zsh.enable = true;
    }
    {
      nixos.user.sharedModules = [(homeInputs:
      {
        config =
        {
          # set bash history file path, avoid overwriting zsh history
          programs.bash = { enable = true; historyFile =  "${homeInputs.config.xdg.dataHome}/bash/bash_history"; };
          home.shell.enableBashIntegration = true;
        };
      })];
    }
    {
      programs.git =
      {
        enable = true;
        # do not use gitFull, otherwise it will use its own ssh
        # package = inputs.pkgs.gitFull;
        lfs = { enable = true; enablePureSSHTransfer = true; };
        config =
        {
          init.defaultBranch = "main";
          core.quotepath = false;
          lfs.ssh.automultiplex = false; # 避免 lfs 一直要求触摸 yubikey
          receive.denyCurrentBranch = "warn"; # 允许 push 到非 bare 的仓库
          merge.ours.driver = true; # 允许 .gitattributes 中设置的 merge=ours 生效
          advice.addIgnoredFile = false; # 关闭 add 忽略文件时的提示
          commit.verbose = true; # always show diff when commit, even if no -v is given
        };
      };
    }
  ];
}
