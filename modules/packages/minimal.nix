inputs:
{
  options.nixos.packages.minimal = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) minimal; in inputs.lib.mkIf (minimal != null)
  {
    nixos.packages.packages =
    {
      _packages = with inputs.pkgs;
      [
        # basic tools
        beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq yq-go ipfetch localPackages.pslist
        fastfetch reptyr duc ncdu progress libva-utils ksh neofetch dateutils glib cryptsetup i2c-tools
        # lsxx
        pciutils usbutils lshw util-linux lsof dmidecode lm_sensors hwloc acpica-tools ethtool
        # top
        iotop iftop htop powertop s-tui
        # editor
        nano bat
        # downloader
        wget aria2 curl yt-dlp ffsend
        # file manager
        tree eza trash-cli lsd broot file xdg-ninja mlocate
        # compress
        pigz upx unzip zip lzip p7zip rpm
        (if inputs.pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then rar else emptyDirectory)
        # file system management
        sshfs e2fsprogs compsize exfatprogs
        # disk management
        smartmontools hdparm gptfdisk
        (if inputs.pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then megacli else emptyDirectory)
        # encryption and authentication
        apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f yubico-piv-tool libfido2
        # networking
        ipset iptables iproute2 dig nettools traceroute tcping-go whois tcpdump nmap inetutils wireguard-tools openvpn
        parted
        # nix tools
        nix-output-monitor nix-tree ssh-to-age nix-inspect
        # development
        gdb try rr hexo-cli gh hugo
        # build failed on aarch64
        (if inputs.pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then nix-init else emptyDirectory)
        (octodns.withProviders (_: with octodns-providers; [ cloudflare ]))
        # stupid things
        toilet dotacat localPackages.stickerpicker graph-easy tokei
        # shell
        # somehow fish does not compile on aarch64
        (if inputs.config.nixos.model.arch == "x86_64" then kitty else emptyDirectory)
      ]
        ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ]);
    };
    programs =
    {
      nix-index-database.comma.enable = true;
      nix-index.enable = true;
      command-not-found.enable = false;
      autojump.enable = true;
      mosh.enable = true;
    };
    services =
    {
      udev.packages = with inputs.pkgs; [ yubikey-personalization libfido2 ];
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
      { setuid = true; owner = "root"; group = "root"; source = "${inputs.pkgs.compsize}/bin/compsize"; };
  };
}
