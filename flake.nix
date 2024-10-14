{
  description = "CNH's NixOS Flake";

  inputs =
  {
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-unstable";
    "nixpkgs-23.11".url = "github:CHN-beta/nixpkgs/nixos-23.11";
    "nixpkgs-23.05".url = "github:CHN-beta/nixpkgs/nixos-23.05";
    "nixpkgs-22.11".url = "github:NixOS/nixpkgs/nixos-22.11";
    "nixpkgs-22.05".url = "github:NixOS/nixpkgs/nixos-22.05";
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix =
    {
      url = "github:Mic92/sops-nix";
      inputs = { nixpkgs.follows = "nixpkgs"; nixpkgs-stable.follows = "nixpkgs"; };
    };
    aagl = { url = "github:ezKEa/aagl-gtk-on-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur-xddxdd = { url = "github:xddxdd/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-vscode-extensions = { url = "github:nix-community/nix-vscode-extensions"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence.url = "github:nix-community/impermanence";
    qchem = { url = "github:Nix-QChem/NixOS-QChem/master"; inputs.nixpkgs.follows = "nixpkgs"; };
    plasma-manager =
    {
      url = "github:pjones/plasma-manager";
      inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; };
    };
    nur-linyinfeng = { url = "github:linyinfeng/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware.url = "github:CHN-beta/nixos-hardware";
    envfs = { url = "github:Mic92/envfs"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-fast-build = { url = "github:/Mic92/nix-fast-build"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    chaotic =
    {
      url = "github:chaotic-cx/nyx";
      inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; };
    };
    gricad = { url = "github:Gricad/nur-packages"; flake = false; };
    catppuccin.url = "github:catppuccin/nix";
    bscpkgs = { url = "git+https://git.chn.moe/chn/bscpkgs.git"; inputs.nixpkgs.follows = "nixpkgs"; };
    poetry2nix = { url = "github:nix-community/poetry2nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    winapps = { url = "github:winapps-org/winapps/feat-nix-packaging"; inputs.nixpkgs.follows = "nixpkgs"; };

    misskey = { url = "git+https://github.com/CHN-beta/misskey?submodules=1"; flake = false; };
    rsshub = { url = "github:DIYgod/RSSHub"; flake = false; };
    zpp-bits = { url = "github:eyalz800/zpp_bits"; flake = false; };
    concurrencpp = { url = "github:David-Haim/concurrencpp"; flake = false; };
    cppcoro = { url = "github:Garcia6l20/cppcoro"; flake = false; };
    date = { url = "github:HowardHinnant/date"; flake = false; };
    eigen = { url = "gitlab:libeigen/eigen"; flake = false; };
    matplotplusplus = { url = "github:alandefreitas/matplotplusplus"; flake = false; };
    nameof = { url = "github:Neargye/nameof"; flake = false; };
    nodesoup = { url = "github:olvb/nodesoup"; flake = false; };
    tgbot-cpp = { url = "github:reo7sp/tgbot-cpp"; flake = false; };
    v-sim = { url = "gitlab:l_sim/v_sim"; flake = false; };
    rycee = { url = "gitlab:rycee/nur-expressions"; flake = false; };
    blurred-wallpaper = { url = "github:bouteillerAlan/blurredwallpaper"; flake = false; };
    slate = { url = "github:TheBigWazz/Slate"; flake = false; };
    linux-surface = { url = "github:linux-surface/linux-surface"; flake = false; };
    lepton = { url = "github:black7375/Firefox-UI-Fix"; flake = false; };
    lmod = { url = "github:TACC/Lmod"; flake = false; };
    mumax = { url = "github:CHN-beta/mumax"; flake = false; };
    kylin-virtual-keyboard = { url = "git+https://gitee.com/openkylin/kylin-virtual-keyboard.git"; flake = false; };
    cjktty = { url = "github:CHN-beta/cjktty-patches"; flake = false; };
    zxorm = { url = "github:CHN-beta/zxorm"; flake = false; };
    openxlsx = { url = "github:troldal/OpenXLSX?rev=f85f7f1bd632094b5d78d4d1f575955fc3801886"; flake = false; };
    sqlite-orm = { url = "github:fnc12/sqlite_orm"; flake = false; };
    sockpp = { url = "github:fpagliughi/sockpp"; flake = false; };
    git-lfs-transfer = { url = "github:charmbracelet/git-lfs-transfer"; flake = false; };
    nc4nix = { url = "github:helsinki-systems/nc4nix"; flake = false; };
    hextra = { url = "github:imfing/hextra"; flake = false; };
    nu-scripts = { url = "github:nushell/nu_scripts"; flake = false; };
    py4vasp = { url = "github:vasp-dev/py4vasp"; flake = false; };
    pocketfft = { url = "github:mreineck/pocketfft"; flake = false; };
    blog = { url = "git+https://git.chn.moe/chn/blog.git"; flake = false; };
    nixos-wallpaper = { url = "git+https://git.chn.moe/chn/nixos-wallpaper.git"; flake = false; };
    spectroscopy = { url = "github:skelton-group/Phonopy-Spectroscopy"; flake = false; };
  };

  outputs = inputs: let localLib = import ./flake/lib.nix inputs.nixpkgs.lib; in
  {
    packages.x86_64-linux = import ./flake/packages.nix { inherit inputs localLib; };
    nixosConfigurations = import ./flake/nixos.nix { inherit inputs localLib; };
    overlays.default = final: prev:
      { localPackages = (import ./packages { inherit localLib; pkgs = final; topInputs = inputs; }); };
    config = { archive = false; branch = "production"; };
    devShells.x86_64-linux = import ./flake/dev.nix { inherit inputs; };
    src = import ./flake/src.nix { inherit inputs; };
  };
}
