{
  description = "CNH's NixOS Flake";

  inputs =
  {
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-2505.url = "github:CHN-beta/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:CHN-beta/nixpkgs/nixos-24.11";
    nixpkgs-2311.url = "github:CHN-beta/nixpkgs/nixos-23.11";
    nixpkgs-2305.url = "github:CHN-beta/nixpkgs/nixos-23.05";
    home-manager = { url = "github:nix-community/home-manager/release-25.11"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur-xddxdd = { url = "github:CHN-beta/nur-xddxdd"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence.url = "github:CHN-beta/impermanence";
    nur-linyinfeng = { url = "github:linyinfeng/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    catppuccin = { url = "github:catppuccin/nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    bscpkgs = { url = "github:CHN-beta/bscpkgs"; inputs.nixpkgs.follows = "nixpkgs"; };
    aagl = { url = "github:ezKEa/aagl-gtk-on-nix/release-25.11"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixvirt = { url = "github:CHN-beta/NixVirt"; inputs.nixpkgs.follows = "nixpkgs"; };
    buildproxy = { url = "github:polygon/nix-buildproxy"; inputs.nixpkgs.follows = "nixpkgs"; };
    niri = { url = "github:CHN-beta/niri-flake"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix4vscode =
    {
      url = "github:nix-community/nix4vscode?rev=6c603c201b11dafda616940bac1f295144ac1c41";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dankmaterialshell = { url = "github:AvengeMedia/DankMaterialShell"; inputs.nixpkgs.follows = "nixpkgs"; };
    harmonia.url = "github:nix-community/harmonia";
    dms-plugin-registry = { url = "github:AvengeMedia/dms-plugin-registry"; inputs.nixpkgs.follows = "nixpkgs"; };
    chinese-fonts = { url = "github:brsvh/chinese-fonts-overlay"; inputs.nixpkgs.follows = "nixpkgs"; };

    misskey = { url = "git+https://github.com/CHN-beta/misskey?ref=chn-mod&submodules=1"; flake = false; };
    rsshub = { url = "github:DIYgod/RSSHub"; flake = false; };
    zpp-bits = { url = "github:eyalz800/zpp_bits"; flake = false; };
    concurrencpp = { url = "github:David-Haim/concurrencpp"; flake = false; };
    cppcoro = { url = "github:Garcia6l20/cppcoro"; flake = false; };
    date = { url = "github:HowardHinnant/date"; flake = false; };
    matplotplusplus = { url = "github:alandefreitas/matplotplusplus"; flake = false; };
    nameof = { url = "github:Neargye/nameof"; flake = false; };
    tgbot-cpp = { url = "github:reo7sp/tgbot-cpp"; flake = false; };
    v-sim = { url = "gitlab:l_sim/v_sim/b76501454b489715495a255347d5c7f756e1207f"; flake = false; };
    rycee = { url = "gitlab:rycee/nur-expressions"; flake = false; };
    lepton = { url = "github:black7375/Firefox-UI-Fix"; flake = false; };
    mumax = { url = "github:mumax/3"; flake = false; };
    openxlsx = { url = "github:troldal/OpenXLSX?rev=f85f7f1bd632094b5d78d4d1f575955fc3801886"; flake = false; };
    sqlite-orm = { url = "github:fnc12/sqlite_orm"; flake = false; };
    nc4nix = { url = "github:helsinki-systems/nc4nix"; flake = false; };
    hextra = { url = "github:imfing/hextra"; flake = false; };
    nu-scripts = { url = "github:nushell/nu_scripts"; flake = false; };
    py4vasp = { url = "github:vasp-dev/py4vasp?ref=v0.10.2"; flake = false; };
    pocketfft = { url = "github:mreineck/pocketfft"; flake = false; };
    blog = { url = "git+https://git.chn.moe/chn/blog-public.git?lfs=1"; flake = false; };
    vaspberry = { url = "github:Infant83/VASPBERRY"; flake = false; };
    stickerpicker = { url = "github:maunium/stickerpicker"; flake = false; };
    fancy-motd = { url = "github:CHN-beta/fancy-motd"; flake = false; };
    mac-style = { url = "github:SergioRibera/s4rchiso-plymouth-theme?lfs=1"; flake = false; };
    phono3py = { url = "github:phonopy/phono3py/v3.19.4"; flake = false; };
    sticker = { url = "git+https://git.chn.moe/chn/sticker.git?lfs=1"; flake = false; };
    speedtest = { url = "github:librespeed/speedtest"; flake = false; };
    pybinding = { url = "git+https://github.com/dean0x7d/pybinding?submodules=1"; flake = false; };
    brokenaxes = { url = "github:bendichter/brokenaxes"; flake = false; };
    mirism-old = { url = "github:CHN-beta/mirism-old-public"; flake = false; };
    sqlgen = { url = "git+https://github.com/getml/sqlgen?submodules=1"; flake = false; };
    reflectcpp = { url = "git+https://github.com/getml/reflect-cpp?submodules=1"; flake = false; };
    linux-asus = { url = "github:CHN-beta/linux-g14/6.18"; flake = false; };
    ufo = { url = "git+https://git.chn.moe/chn/ufo.git?lfs=1"; flake = false; };
    gitea-robots-txt = { url = "https://gitea.com/robots.txt"; flake = false; };
    ugreen = { url = "github:miskcoo/ugreen_leds_controller"; flake = false; };
    asmroner = { url = "github:fireinrain/asmr-downloader"; flake = false; };
    dwproton = { url = "github:imaviso/dwproton-flake"; flake = false; };
  };

  outputs = inputs: let localLib = import ./flake/lib inputs.nixpkgs.lib; in
  {
    packages.x86_64-linux = import ./flake/packages.nix { inherit inputs localLib; };
    nixosConfigurations = import ./flake/nixos.nix { inherit inputs localLib; };
    overlays.default = final: prev:
    {
      localPkgs = (import ./packages { inherit localLib; pkgs = final; flakeInputs = inputs; });
      pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++
        [(finalPython: prevPython: final.localPkgs.pythonOverlay finalPython)];
    };
    nixosModules.default = { imports = localLib.mkModules [ ./modules ./devices/cross ]; };
    config.dns = inputs.self.packages.x86_64-linux.dns-push.meta.config;
    devShells.x86_64-linux = import ./flake/dev.nix { inherit inputs; };
    src = import ./flake/src.nix { inherit inputs; };
    apps.x86_64-linux.dns-push = { type = "app"; program = "${inputs.self.packages.x86_64-linux.dns-push}"; };
  };
}
