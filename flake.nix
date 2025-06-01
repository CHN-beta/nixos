{
  description = "CNH's NixOS Flake";

  inputs =
  {
    self.lfs = true;
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:CHN-beta/nixpkgs/nixos-24.11";
    nixpkgs-2311.url = "github:CHN-beta/nixpkgs/nixos-23.11";
    nixpkgs-2305.url = "github:CHN-beta/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:CHN-beta/nixpkgs/nixos-unstable";
    home-manager = { url = "github:CHN-beta/home-manager/release-25.05"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur-xddxdd = { url = "github:xddxdd/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-vscode-extensions =
    {
      url = "github:nix-community/nix-vscode-extensions?ref=4a7f92bdabb365936a8e8958948536cc2ceac7ba";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:CHN-beta/impermanence";
    plasma-manager =
    {
      url = "github:pjones/plasma-manager";
      inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; };
    };
    catppuccin = { url = "github:catppuccin/nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    bscpkgs = { url = "github:CHN-beta/bscpkgs"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixvirt = { url = "github:CHN-beta/NixVirt"; inputs.nixpkgs.follows = "nixpkgs"; };
    buildproxy = { url = "github:polygon/nix-buildproxy"; inputs.nixpkgs.follows = "nixpkgs"; };

    misskey = { url = "git+https://github.com/CHN-beta/misskey?submodules=1"; flake = false; };
    rsshub = { url = "github:DIYgod/RSSHub"; flake = false; };
    zpp-bits = { url = "github:eyalz800/zpp_bits"; flake = false; };
    concurrencpp = { url = "github:David-Haim/concurrencpp"; flake = false; };
    cppcoro = { url = "github:Garcia6l20/cppcoro"; flake = false; };
    date = { url = "github:HowardHinnant/date"; flake = false; };
    matplotplusplus = { url = "github:alandefreitas/matplotplusplus"; flake = false; };
    nameof = { url = "github:Neargye/nameof"; flake = false; };
    tgbot-cpp = { url = "github:reo7sp/tgbot-cpp"; flake = false; };
    v-sim = { url = "gitlab:l_sim/v_sim/master"; flake = false; };
    rycee = { url = "gitlab:rycee/nur-expressions"; flake = false; };
    lepton = { url = "github:black7375/Firefox-UI-Fix"; flake = false; };
    mumax = { url = "github:CHN-beta/mumax"; flake = false; };
    openxlsx = { url = "github:troldal/OpenXLSX"; flake = false; };
    sqlite-orm = { url = "github:fnc12/sqlite_orm"; flake = false; };
    nc4nix = { url = "github:helsinki-systems/nc4nix"; flake = false; };
    hextra = { url = "github:imfing/hextra"; flake = false; };
    nu-scripts = { url = "github:nushell/nu_scripts"; flake = false; };
    py4vasp = { url = "github:vasp-dev/py4vasp"; flake = false; };
    pocketfft = { url = "github:mreineck/pocketfft"; flake = false; };
    blog = { url = "git+https://git.chn.moe/chn/blog-public.git?lfs=1"; flake = false; };
    nixos-wallpaper = { url = "git+https://git.chn.moe/chn/nixos-wallpaper.git?lfs=1"; flake = false; };
    vaspberry = { url = "github:Infant83/VASPBERRY"; flake = false; };
    ufo = { url = "git+https://git.chn.moe/chn/ufo.git?lfs=1"; flake = false; };
    stickerpicker = { url = "github:maunium/stickerpicker"; flake = false; };
    fancy-motd = { url = "github:CHN-beta/fancy-motd"; flake = false; };
    mac-style = { url = "github:SergioRibera/s4rchiso-plymouth-theme?lfs=1"; flake = false; };
    phono3py = { url = "github:phonopy/phono3py"; flake = false; };
  };

  outputs = inputs: let localLib = import ./flake/lib.nix inputs.nixpkgs.lib; in
  {
    packages.x86_64-linux = import ./flake/packages.nix { inherit inputs localLib; };
    nixosConfigurations = import ./flake/nixos.nix { inherit inputs localLib; };
    overlays.default = final: prev:
      { localPackages = (import ./packages { inherit localLib; pkgs = final; topInputs = inputs; }); };
    config =
    {
      branch = import ./flake/branch.nix;
      dns = inputs.self.packages.x86_64-linux.dns-push.meta.config;
    };
    devShells.x86_64-linux = import ./flake/dev.nix { inherit inputs; };
    src = import ./flake/src.nix { inherit inputs; };
    apps.x86_64-linux.dns-push = { type = "app"; program = "${inputs.self.packages.x86_64-linux.dns-push}"; };
  };
}
