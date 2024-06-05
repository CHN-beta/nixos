inputs:
{
  config = inputs.lib.mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
  {
    nixos.packages._packages = with inputs.pkgs;
    [
      # basic tools
      beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq zellij ipfetch localPackages.pslist
      fastfetch reptyr nushellFull duc
      # lsxx
      pciutils usbutils lshw util-linux lsof dmidecode lm_sensors
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
      nix-output-monitor nix-tree ssh-to-age (callPackage "${inputs.topInputs.nix-fast-build}" {}) nix-inspect
      # development
      gdb try inputs.topInputs.plasma-manager.packages.${inputs.pkgs.system}.rc2nix
      # stupid things
      toilet lolcat
    ]
    ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ])
    ++ (inputs.lib.optional (inputs.config.nixos.system.nixpkgs.arch == "x86_64") rar);
    programs =
    {
      nix-index-database.comma.enable = true;
      nix-index.enable = true;
      command-not-found.enable = false;
      autojump.enable = true;
      direnv = { enable = true; nix-direnv.enable = true; };
    };
    services.udev.packages = with inputs.pkgs; [ yubikey-personalization libfido2 ];
    home-manager = { useGlobalPkgs = true; useUserPackages = true; };
  };
}
