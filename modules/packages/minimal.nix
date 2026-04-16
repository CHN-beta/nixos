{ lib, config, pkgs, ... }:
{
  config = lib.mkMerge
  [
    {
      environment.systemPackages = with pkgs;
      [
        # basic tools
        beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq yq-go
        ipfetch localPkgs.pslist
        fastfetch reptyr duc ncdu progress libva-utils ksh neofetch
        dateutils glib cryptsetup i2c-tools trash-cli cpuid
        stress-ng
        (if config.nixos.system.nixpkgs.cuda == null then emptyDirectory else gpu-burn)
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
        smartmontools hdparm gptfdisk
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
      programs.ssh =
      {
        # maybe better network performance
        package = pkgs.openssh_hpn;
        startAgent = true;
        enableAskPassword = true;
        askPassword = "${pkgs.systemd}/bin/systemd-ask-password";
        extraConfig = "AddKeysToAgent yes";
        knownHosts =
          let servers =
          {
            hpc =
            {
              ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIDVpsQW3kZt5alHC6mZhay3ZEe2fRGziG4YJWCv2nn/O";
              hostnames = [ "hpc.xmu.edu.cn" ];
            };
            hpc2 =
            {
              ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIMv22sVyZ0RgFrdrHKbqOvdhq7TKZKImKwbbTbtO5jqy";
              hostnames = [ "hpc.xmu.edu.cn" ];
            };
            github =
            {
              ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
              hostnames = [ "github.com" ];
            };
          };
          in builtins.mapAttrs (_: v: { publicKey = "ssh-ed25519 ${v.ed25519}"; hostNames = v.hostnames; }) servers;
      };
      environment.sessionVariables.SSH_ASKPASS_REQUIRE = "prefer";
      nixos.user.sharedModules =
      [(hmInputs: {
        config.programs.ssh =
        {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks = builtins.listToAttrs (builtins.map
            (host:
            {
              name = host;
              value =
              {
                host = host;
                hostname = "hpc.xmu.edu.cn";
                user = host;
              };
            })
            [ "wlin" "hwang" ])
          // rec {
            gitea = { host = "gitea"; hostname = "ssh.git.chn.moe"; };
            jykang =
            {
              host = "jykang";
              hostname = "hpc.xmu.edu.cn";
              user = "jykang";
              forwardAgent = true;
              extraOptions.AddKeysToAgent = "yes";
            };
            "tinc0.jykang" = jykang // { host = "tinc0.jykang"; proxyJump = "tinc0.nas"; };
            "*" =
            {
              controlMaster = "auto";
              controlPersist = "1m";
              compression = true;
              controlPath = "~/.ssh/master-%r@%n:%p";
            };
          };
        };
      })];
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
              source ${flakeInputs.nu-scripts}/aliases/git/git-aliases.nu
              $env.PATH = ($env.PATH | split row (char esep) | append "~/bin")
            '';
          };
          carapace.enable = true;
          oh-my-posh =
          {
            enable = true;
            enableZshIntegration = false;
            settings = localLib.deepReplace
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
          package = pkgs.pkgs-unstable.ghostty;
          settings = { scrollback-limit = 100000000; keybind = "ctrl+shift+r=reset"; linux-cgroup = "always"; };
        };
      }];
      environment.systemPackages = [ pkgs.pkgs-unstable.ghostty ];
    }
    {
      environment.systemPackages = [ pkgs.btop ];
      nixos.user.sharedModules =
        [{ config.programs.btop = { enable = true; settings.btrfs_group_subvolumes = true; }; }];
    }
  ];
}
