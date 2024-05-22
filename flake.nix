{
  description = "CNH's NixOS Flake";

  inputs =
  {
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:CHN-beta/nixpkgs/nixos-unstable";
    "nixpkgs-23.11".url = "github:CHN-beta/nixpkgs/nixos-23.11";
    "nixpkgs-23.05".url = "github:CHN-beta/nixpkgs/nixos-23.05";
    "nixpkgs-22.11".url = "github:NixOS/nixpkgs/nixos-22.11";
    "nixpkgs-22.05".url = "github:NixOS/nixpkgs/nixos-22.05";
    home-manager = { url = "github:nix-community/home-manager/master"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix =
    {
      url = "github:Mic92/sops-nix";
      inputs = { nixpkgs.follows = "nixpkgs"; nixpkgs-stable.follows = "nixpkgs"; };
    };
    aagl = { url = "github:ezKEa/aagl-gtk-on-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };
    nur.url = "github:nix-community/NUR";
    nixos-cn = { url = "github:nixos-cn/flakes"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur-xddxdd = { url = "github:xddxdd/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-vscode-extensions = { url = "github:nix-community/nix-vscode-extensions"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence.url = "github:nix-community/impermanence";
    qchem = { url = "github:Nix-QChem/NixOS-QChem/master"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixd = { url = "github:nix-community/nixd"; inputs.nixpkgs.follows = "nixpkgs"; };
    napalm = { url = "github:nix-community/napalm"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixpak = { url = "github:nixpak/nixpak"; inputs.nixpkgs.follows = "nixpkgs"; };
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
    plasma-manager =
    {
      url = "github:pjones/plasma-manager";
      inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; };
    };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; inputs.nixpkgs.follows = "nixpkgs"; };
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
    win11os-kde = { url = "github:yeyushengfan258/Win11OS-kde"; flake = false; };
    fluent-kde = { url = "github:vinceliuice/Fluent-kde"; flake = false; };
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
    openxlsx = { url = "github:troldal/OpenXLSX"; flake = false; };
    sqlite-orm = { url = "github:fnc12/sqlite_orm"; flake = false; };

    # does not support lfs yet
    # nixos-wallpaper = { url = "git+https://git.chn.moe/chn/nixos-wallpaper.git"; flake = false; };
  };

  outputs = inputs:
    let
      localLib = import ./local/lib inputs.nixpkgs.lib;
      devices = builtins.filter (dir: (builtins.readDir ./devices/${dir})."default.nix" or null == "regular" )
        (builtins.attrNames (builtins.readDir ./devices));
    in
    {
      packages.x86_64-linux =
        let pkgs = (import inputs.nixpkgs
        {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [ inputs.self.overlays.default ];
        });
        in
        {
          default = inputs.nixpkgs.legacyPackages.x86_64-linux.writeText "systems"
            (builtins.concatStringsSep "\n" (builtins.map
              (system: builtins.toString inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel)
              devices));
          hpcstat =
            let openssh = (pkgs.pkgsStatic.openssh.override { withLdns = false; etcDir = null; }).overrideAttrs
              (prev: { doCheck = false; patches = prev.patches ++ [ ./local/pkgs/hpcstat/openssh.patch ];});
            in pkgs.pkgsStatic.localPackages.hpcstat.override { inherit openssh; standalone = true; };
        }
        // (
          builtins.listToAttrs (builtins.map
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
                  { localPackages = import ./local/pkgs (moduleInputs // { pkgs = final; }); })]; })
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
                { localPackages = import ./local/pkgs (moduleInputs // { pkgs = final; }); })]; })
              ./modules
              ./devices/pi3b
            ];
          };
        }
      );
      deploy =
      {
        sshUser = "root";
        user = "root";
        fastConnection = true;
        autoRollback = false;
        magicRollback = false;
        nodes = builtins.listToAttrs (builtins.map
          (node:
          {
            name = node;
            value =
            {
              hostname = node;
              profiles.system.path = inputs.self.nixosConfigurations.${node}.pkgs.deploy-rs.lib.activate.nixos
                inputs.self.nixosConfigurations.${node};
            };
          })
          [ "vps6" "vps7" "nas" "surface" "xmupc1" "xmupc2" "pi3b" ]
        );
      };
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks inputs.self.deploy) inputs.deploy-rs.lib;
      overlays.default = final: prev:
        { localPackages = (import ./local/pkgs { inherit (inputs) lib; pkgs = final; topInputs = inputs; }); };
      config.archive = false;
      devShells.x86_64-linux =
        let pkgs = (import inputs.nixpkgs
        {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [ inputs.self.overlays.default ];
        });
        in
        {
          biu = pkgs.mkShell
          {
            packages = with pkgs; [ pkg-config cmake ninja clang-tools_17 ];
            buildInputs =
              (with pkgs; [ fmt boost magic-enum libbacktrace eigen range-v3 ])
              ++ (with pkgs.localPackages; [ concurrencpp tgbot-cpp nameof ]);
            # hardeningDisable = [ "all" ];
            # NIX_DEBUG = "1";
          };
          hpcstat = pkgs.mkShell
          {
            inputsFrom = [ inputs.self.packages.x86_64-linux.hpcstat ];
            packages = [ pkgs.clang-tools_17 ];
            CMAKE_EXPORT_COMPILE_COMMANDS = "1";
          };
        };
    };
}
