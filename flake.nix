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
    bscpkgs = { url = "git+https://pm.bsc.es/gitlab/rarias/bscpkgs.git"; inputs.nixpkgs.follows = "nixpkgs"; };
    poetry2nix = { url = "github:CHN-beta/poetry2nix"; inputs.nixpkgs.follows = "nixpkgs"; };

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
    pocketfft = { url = "github:/mreineck/pocketfft"; flake = false; };

    # does not support lfs yet
    # nixos-wallpaper = { url = "git+https://git.chn.moe/chn/nixos-wallpaper.git"; flake = false; };
  };

  outputs = inputs:
    let
      localLib = import ./lib.nix inputs.nixpkgs.lib;
      devices = builtins.filter (dir: (builtins.readDir ./devices/${dir})."default.nix" or null == "regular" )
        (builtins.attrNames (builtins.readDir ./devices));
    in
    {
      packages.x86_64-linux = rec
      {
        pkgs = (import inputs.nixpkgs
        {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [ inputs.self.overlays.default ];
        });
        default = inputs.nixpkgs.legacyPackages.x86_64-linux.writeText "systems"
          (builtins.concatStringsSep "\n" (builtins.map
            (system: builtins.toString inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel)
            devices));
        hpcstat =
          let
            openssh = (pkgs.pkgsStatic.openssh.override { withLdns = false; etcDir = null; }).overrideAttrs
              (prev: { doCheck = false; patches = prev.patches ++ [ ./packages/hpcstat/openssh.patch ];});
            duc = pkgs.pkgsStatic.duc.override { enableCairo = false; cairo = null; pango = null; };
          in pkgs.pkgsStatic.localPackages.hpcstat.override
            { inherit openssh duc; standalone = true; version = inputs.self.rev or "dirty"; };
        ufo =
          let
            range-v3 = pkgs.pkgsStatic.range-v3.overrideAttrs (prev:
            {
              cmakeFlags = prev.cmakeFlags or []
                ++ [ "-DRANGE_V3_DOCS=OFF" "-DRANGE_V3_TESTS=OFF" "-DRANGE_V3_EXAMPLES=OFF" ];
              doCheck = false;
            });
            tbb = pkgs.pkgsStatic.tbb_2021_11.overrideAttrs (prev: { cmakeFlags = prev.cmakeFlags or [] ++
              [ "-DTBB_TEST=OFF" ]; });
            biu = pkgs.pkgsStatic.localPackages.biu.override { inherit range-v3; };
            matplotplusplus = pkgs.pkgsStatic.localPackages.matplotplusplus.override { libtiff = null; };
          in pkgs.pkgsStatic.localPackages.ufo.override { inherit biu tbb matplotplusplus; };
        chn-bsub = pkgs.pkgsStatic.localPackages.chn-bsub;
        blog = pkgs.callPackage ./blog { inherit (inputs) hextra; };
      }
      // (builtins.listToAttrs (builtins.map
        (system:
        {
          name = system;
          value = inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel;
        })
        devices)
      );
      nixosConfigurations =
      (
        (builtins.listToAttrs (builtins.map
          (system:
          {
            name = system;
            value = inputs.nixpkgs.lib.nixosSystem
            {
              system = "x86_64-linux";
              specialArgs = { topInputs = inputs; inherit localLib; };
              modules = localLib.mkModules
              [
                (moduleInputs: { config.nixpkgs.overlays = [(prev: final:
                  # replace pkgs with final to avoid infinite recursion
                  { localPackages = import ./packages (moduleInputs // { pkgs = final; }); })]; })
                ./modules
                ./devices/${system}
              ];
            };
          })
          devices))
        // {
          pi3b = inputs.nixpkgs.lib.nixosSystem
          {
            system = "aarch64-linux";
            specialArgs = { topInputs = inputs; inherit localLib; };
            modules = localLib.mkModules
            [
              (moduleInputs: { config.nixpkgs.overlays = [(prev: final:
                # replace pkgs with final to avoid infinite recursion
                { localPackages = import ./packages (moduleInputs // { pkgs = final; }); })]; })
              ./modules
              ./devices/pi3b
            ];
          };
        }
      );
      overlays.default = final: prev:
        { localPackages = (import ./packages { inherit (inputs) lib; pkgs = final; topInputs = inputs; }); };
      config = { archive = false; branch = "production"; };
      devShells.x86_64-linux = let inherit (inputs.self.nixosConfigurations.pc) pkgs; in
      {
        biu = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
        {
          inputsFrom = [ pkgs.localPackages.biu ];
          packages = [ pkgs.clang-tools_18 ];
          CMAKE_EXPORT_COMPILE_COMMANDS = "1";
        };
        hpcstat = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
        {
          inputsFrom = [ (pkgs.localPackages.hpcstat.override { version = null; }) ];
          CMAKE_EXPORT_COMPILE_COMMANDS = "1";
        };
        sbatch-tui = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
        {
          inputsFrom = [ pkgs.localPackages.sbatch-tui ];
          CMAKE_EXPORT_COMPILE_COMMANDS = "1";
        };
        ufo = pkgs.mkShell.override { stdenv = pkgs.clang18Stdenv; }
        {
          inputsFrom = [ (pkgs.localPackages.ufo.override { version = null; }) ];
          packages = [ pkgs.clang-tools_18 ];
          CMAKE_EXPORT_COMPILE_COMMANDS = "1";
        };
        chn-bsub = pkgs.mkShell
        {
          inputsFrom = [ pkgs.localPackages.chn-bsub ];
          packages = [ pkgs.clang-tools_18 ];
          CMAKE_EXPORT_COMPILE_COMMANDS = "1";
        };
        winjob =
          let inherit (pkgs) clang-tools_18; in let inherit (inputs.self.packages.x86_64-w64-mingw32) pkgs winjob;
          in pkgs.mkShell.override { stdenv = pkgs.gcc14Stdenv; }
          {
            inputsFrom = [ winjob ];
            packages = [ clang-tools_18 ];
            CMAKE_EXPORT_COMPILE_COMMANDS = "1";
          };
      };
      src = let inherit (inputs.self.packages.x86_64-linux) pkgs; in
      {
        nixos-wallpaper = pkgs.fetchgit
        {
          url = "https://git.chn.moe/chn/nixos-wallpaper.git";
          rev = "1ad78b20b21c9f4f7ba5f4c897f74276763317eb";
          sha256 = "0faahbzsr44bjmwr6508wi5hg59dfb57fzh5x6jh7zwmv4pzhqlb";
          fetchLFS = true;
        };
      };
    };
}
