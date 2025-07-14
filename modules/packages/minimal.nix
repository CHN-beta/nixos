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
        beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq yq ipfetch localPackages.pslist
        fastfetch reptyr duc ncdu progress libva-utils ksh neofetch dateutils kitty glib
        # lsxx
        pciutils usbutils lshw util-linux lsof dmidecode lm_sensors hwloc acpica-tools ethtool
        # top
        iotop iftop htop btop powertop s-tui
        # editor
        nano bat
        # downloader
        wget aria2 curl yt-dlp ffsend
        # file manager
        tree eza trash-cli lsd broot file xdg-ninja mlocate
        # compress
        pigz upx unzip zip lzip p7zip rar
        # file system management
        sshfs e2fsprogs compsize exfatprogs
        # disk management
        smartmontools hdparm gptfdisk megacli
        # encryption and authentication
        apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f yubico-piv-tool libfido2
        # networking
        ipset iptables iproute2 dig nettools traceroute tcping-go whois tcpdump nmap inetutils wireguard-tools openvpn
        parted
        # nix tools
        nix-output-monitor nix-tree ssh-to-age nix-inspect
        # development
        gdb try rr hexo-cli gh nix-init hugo
        (octodns.withProviders (_: with octodns-providers; [ cloudflare ]))
        # stupid things
        toilet lolcat localPackages.stickerpicker graph-easy
        # office
        pdfgrep ffmpeg-full hdf5
      ]
        ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ])
        ++ (inputs.lib.optionals (inputs.config.nixos.system.gui.implementation == "kde")
          [ inputs.topInputs.plasma-manager.packages.${inputs.pkgs.system}.rc2nix ]);
      _pythonPackages = [(pythonPackages: with pythonPackages;
      [
        openai python-telegram-bot fastapi-cli pypdf2 pandas matplotlib plotly gunicorn redis jinja2 certifi 
        charset-normalizer idna orjson psycopg2 inquirerpy requests tqdm pydbus
        # allow pandas read odf
        odfpy
        # for vasp plot-workfunc.py
        ase
      ])];
    };
    programs =
    {
      nix-index-database.comma.enable = true;
      nix-index.enable = true;
      command-not-found.enable = false;
      autojump.enable = true;
      direnv = { enable = true; nix-direnv.enable = true; };
      mosh.enable = true;
      yazi.enable = true;
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
