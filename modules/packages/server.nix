inputs:
{
  options.nixos.packages.server = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) server; in inputs.lib.mkIf (server != null)
  {
    nixos.packages.packages =
    {
      _packages = with inputs.pkgs;
      [
        # basic tools
        beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq zellij ipfetch localPackages.pslist
        fastfetch reptyr duc ncdu progress libva-utils ksh neofetch
        # lsxx
        pciutils usbutils lshw util-linux lsof dmidecode lm_sensors
        # top
        iotop iftop htop btop powertop s-tui
        # editor
        nano bat
        # downloader
        wget aria2 curl yt-dlp ffsend
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
        gdb try inputs.topInputs.plasma-manager.packages.${inputs.pkgs.system}.rc2nix rr hexo-cli gh nix-init hugo
        # stupid things
        toilet lolcat
        # office
        todo-txt-cli pdfgrep ffmpeg-full
      ]
        ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ])
        ++ (inputs.lib.optional (inputs.config.nixos.system.nixpkgs.arch == "x86_64") rar);
      _pythonPackages = [(pythonPackages: with pythonPackages;
      [
        openai python-telegram-bot fastapi-cli pypdf2 pandas matplotlib plotly gunicorn redis jinja2
        certifi charset-normalizer idna orjson psycopg2 inquirerpy requests tqdm pydbus
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
      fwupd.enable = true;
    };
    home-manager = { useGlobalPkgs = true; useUserPackages = true; };
    # allow everyone run compsize
    security.wrappers.compsize =
      { setuid = true; owner = "root"; group = "root"; source = "${inputs.pkgs.compsize}/bin/compsize"; };
  };
}
