{
  description = "CNH's NixOS Flake";

  inputs =
  {
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-2305.url = "github:CHN-beta/nixpkgs/nixos-23.05";
    home-manager = { url = "github:nix-community/home-manager/release-23.11"; inputs.nixpkgs.follows = "nixpkgs"; };
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
    nix-alien =
    {
      url = "github:thiagokokada/nix-alien";
      inputs = { nixpkgs.follows = "nixpkgs"; nix-index-database.follows = "nix-index-database"; };
    };
    impermanence.url = "github:nix-community/impermanence";
    qchem = { url = "github:Nix-QChem/NixOS-QChem/release-23.11"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixd = { url = "github:nix-community/nixd"; inputs.nixpkgs.follows = "nixpkgs"; };
    napalm = { url = "github:nix-community/napalm"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixpak = { url = "github:nixpak/nixpak"; inputs.nixpkgs.follows = "nixpkgs"; };
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
    pnpm2nix-nzbr = { url = "github:CHN-beta/pnpm2nix-nzbr"; inputs.nixpkgs.follows = "nixpkgs"; };
    # oneapi
    lmix = { url = "github:CHN-beta/lmix"; inputs.nixpkgs.follows = "nixpkgs"; };
    # nvhpc
    dguibert-nur-packages = { url = "github:CHN-beta/dguibert-nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    plasma-manager =
    {
      url = "github:pjones/plasma-manager";
      inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; };
    };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur-linyinfeng = { url = "github:linyinfeng/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    envfs = { url = "github:Mic92/envfs"; inputs.nixpkgs.follows = "nixpkgs"; };

    misskey = { url = "git+https://github.com/CHN-beta/misskey?submodules=1"; flake = false; };
    rsshub = { url = "github:DIYgod/RSSHub"; flake = false; };
    zpp-bits = { url = "github:eyalz800/zpp_bits"; flake = false; };
    citation-style-language = { url = "git+https://github.com/zepinglee/citeproc-lua?submodules=1"; flake = false; };
    concurrencpp = { url = "github:David-Haim/concurrencpp"; flake = false; };
    cppcoro = { url = "github:Garcia6l20/cppcoro"; flake = false; };
    date = { url = "github:HowardHinnant/date"; flake = false; };
    eigen = { url = "gitlab:libeigen/eigen"; flake = false; };
    matplotplusplus = { url = "github:alandefreitas/matplotplusplus"; flake = false; };
    nameof = { url = "github:Neargye/nameof"; flake = false; };
    nodesoup = { url = "github:olvb/nodesoup"; flake = false; };
    tgbot-cpp = { url = "github:reo7sp/tgbot-cpp"; flake = false; };
    v-sim = { url = "gitlab:l_sim/v_sim"; flake = false; };
  };

  outputs = inputs:
    let
      localLib = import ./local/lib inputs.nixpkgs.lib;
    in
    {
      packages.x86_64-linux =
      {
        default = inputs.nixpkgs.legacyPackages.x86_64-linux.writeText "systems"
          (builtins.concatStringsSep "\n" (builtins.map
            (system: builtins.toString inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel)
            [ "pc" "vps6" "vps7" "nas" "surface" ]));
      }
      // (
        builtins.listToAttrs (builtins.map
          (system:
          {
            name = system;
            value = inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel;
          })
          [ "pc" "vps6" "vps7" "nas" "surface" "xmupc1" ])
      );
      # ssh-keygen -t rsa -C root@pe -f /mnt/nix/persistent/etc/ssh/ssh_host_rsa_key
      # ssh-keygen -t ed25519 -C root@pe -f /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
      # systemd-machine-id-setup --root=/mnt/nix/persistent
      nixosConfigurations = builtins.listToAttrs (builtins.map
        (system:
        {
          name = system;
          value = inputs.nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            specialArgs = { topInputs = inputs; inherit localLib; };
            modules = localLib.mkModules
            [
              (moduleInputs:
              {
                config.nixpkgs.overlays = [(final: prev: { localPackages =
                  import ./local/pkgs { inherit (moduleInputs) lib; pkgs = final; topInputs = inputs; };})];
              })
              ./modules
              ./devices/${system}
            ];
          };
        })
        [ "pc" "vps6" "vps7" "nas" "surface" "xmupc1" ]);
      # sudo HTTPS_PROXY=socks5://127.0.0.1:10884 nixos-install --flake .#bootstrap --option substituters http://127.0.0.1:5000 --option require-sigs false --option system-features gccarch-silvermont
      # nix-serve -p 5000
      # nix copy --substitute-on-destination --to ssh://server /run/current-system
      # nix copy --to ssh://nixos@192.168.122.56 ./result
      # sudo nixos-install --flake .#bootstrap
      #    --option substituters http://192.168.122.1:5000 --option require-sigs false
      # sudo chattr -i var/empty
      # nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
      # sudo nixos-rebuild switch --flake .#vps6 --log-format internal-json -v |& nom --json
      # boot.shell_on_fail systemd.setenv=SYSTEMD_SULOGIN_FORCE=1
      # sudo usbipd
      # ssh -R 3240:127.0.0.1:3240 root@192.168.122.57
      # modprobe vhci-hcd
      # sudo usbip bind -b 3-6
      # usbip attach -r 127.0.0.1 -b 3-6
      # systemd-cryptenroll --fido2-device=auto /dev/vda2
      # systemd-cryptsetup attach root /dev/vda2
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
          [ "vps6" "vps7" "nas" "surface" ]);
      };
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks inputs.self.deploy) inputs.deploy-rs.lib;
      overlays.default = final: prev:
        { localPackages = (import ./local/pkgs { inherit (inputs) lib; pkgs = final; }); };
      config.production = true;
    };
}
