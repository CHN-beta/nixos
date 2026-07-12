{
  description = "CNH's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-26.05";
    nixpkgs-2511.url = "github:CHN-beta/nixpkgs/nixos-25.11";
    nixpkgs-2411.url = "github:CHN-beta/nixpkgs/nixos-24.11";
    nixpkgs-2311.url = "github:CHN-beta/nixpkgs/nixos-23.11";
    nixpkgs-2305.url = "github:CHN-beta/nixpkgs/nixos-23.05";
    home-manager = {
      url = "github:CHN-beta/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur-xddxdd = {
      url = "github:xddxdd/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:CHN-beta/impermanence";
    nur-linyinfeng = {
      url = "github:linyinfeng/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    catppuccin = {
      url = "github:catppuccin/nix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bscpkgs = {
      url = "github:CHN-beta/bscpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvirt = {
      url = "github:CHN-beta/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    buildproxy = {
      url = "github:polygon/nix-buildproxy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    harmonia.url = "github:nix-community/harmonia";
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chinese-fonts = {
      url = "github:brsvh/chinese-fonts-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    hermes.url = "github:NousResearch/hermes-agent";
    camoufox-nix.url = "github:maximoffua/camoufox-nix";

    misskey = {
      url = "git+https://github.com/CHN-beta/misskey?ref=chn-mod&submodules=1";
      flake = false;
    };
    zpp-bits = {
      url = "github:eyalz800/zpp_bits";
      flake = false;
    };
    concurrencpp = {
      url = "github:David-Haim/concurrencpp";
      flake = false;
    };
    cppcoro = {
      url = "github:Garcia6l20/cppcoro";
      flake = false;
    };
    date = {
      url = "github:HowardHinnant/date";
      flake = false;
    };
    matplotplusplus = {
      url = "github:alandefreitas/matplotplusplus";
      flake = false;
    };
    nameof = {
      url = "github:Neargye/nameof";
      flake = false;
    };
    tgbot-cpp = {
      url = "github:reo7sp/tgbot-cpp";
      flake = false;
    };
    v-sim = {
      url = "gitlab:l_sim/v_sim/b76501454b489715495a255347d5c7f756e1207f";
      flake = false;
    };
    rycee = {
      url = "gitlab:rycee/nur-expressions";
      flake = false;
    };
    lepton = {
      url = "github:black7375/Firefox-UI-Fix";
      flake = false;
    };
    mumax = {
      url = "github:mumax/3";
      flake = false;
    };
    openxlsx = {
      url = "github:troldal/OpenXLSX";
      flake = false;
    };
    sqlite-orm = {
      url = "github:fnc12/sqlite_orm";
      flake = false;
    };
    nc4nix = {
      url = "github:helsinki-systems/nc4nix";
      flake = false;
    };
    hextra = {
      url = "github:imfing/hextra";
      flake = false;
    };
    nu-scripts = {
      url = "github:nushell/nu_scripts";
      flake = false;
    };
    # TODO: use fetch pypi
    py4vasp = {
      url = "github:vasp-dev/py4vasp?ref=v0.10.2";
      flake = false;
    };
    pocketfft = {
      url = "github:mreineck/pocketfft";
      flake = false;
    };
    blog = {
      url = "git+https://git.chn.moe/chn/blog-public.git?lfs=1";
      flake = false;
    };
    vaspberry = {
      url = "github:Infant83/VASPBERRY";
      flake = false;
    };
    stickerpicker = {
      url = "github:maunium/stickerpicker";
      flake = false;
    };
    fancy-motd = {
      url = "github:CHN-beta/fancy-motd";
      flake = false;
    };
    mac-style = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme?lfs=1";
      flake = false;
    };
    sticker = {
      url = "git+https://git.chn.moe/chn/sticker.git?lfs=1";
      flake = false;
    };
    pybinding = {
      url = "git+https://github.com/dean0x7d/pybinding?submodules=1";
      flake = false;
    };
    brokenaxes = {
      url = "github:bendichter/brokenaxes";
      flake = false;
    };
    mirism-old = {
      url = "github:CHN-beta/mirism-old-public";
      flake = false;
    };
    sqlgen = {
      url = "git+https://github.com/getml/sqlgen?submodules=1";
      flake = false;
    };
    reflectcpp = {
      url = "git+https://github.com/getml/reflect-cpp?submodules=1";
      flake = false;
    };
    linux-asus = {
      url = "gitlab:asus-linux/linux-g14/7.0";
      flake = false;
    };
    ufo = {
      url = "github:CHN-beta/ufo";
      flake = false;
    };
    gitea-robots-txt = {
      url = "https://gitea.com/robots.txt";
      flake = false;
    };
    ugreen = {
      url = "github:miskcoo/ugreen_leds_controller";
      flake = false;
    };
    asmroner = {
      url = "github:fireinrain/asmr-downloader";
      flake = false;
    };
    dwproton = {
      url = "github:imaviso/dwproton-flake";
      flake = false;
    };
    pydefect = {
      url = "github:kumagai-group/pydefect";
      flake = false;
    };
    matplotlib-label-lines = {
      url = "github:cphyc/matplotlib-label-lines";
      flake = false;
    };
    vise = {
      url = "github:kumagai-group/vise";
      flake = false;
    };
  };

  outputs = inputs: rec {
    lib = import ./lib inputs.self;
    packages.x86_64-linux = import ./packages inputs.self;
    nixosConfigurations = import ./nixosConfigurations inputs.self;
    overlays.default = import ./overlay inputs.self;
    nixosModules.default.imports = lib.mkModules [ ./nixosModules ];
    devShells.x86_64-linux = import ./devShells.nix inputs.self;
    src = import ./src.nix inputs.self;
    apps.x86_64-linux = import ./apps.nix inputs.self;
  };
}
