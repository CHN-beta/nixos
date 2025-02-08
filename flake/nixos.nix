{ inputs, localLib }:
let
  machine = [ "nas" "pc" "pi3b" "vps6" "vps7" "one" ];
  cluster = { srv1 = 4; srv2 = 2; };
in builtins.listToAttrs
(
  (builtins.map
    (system:
    {
      name = system;
      value = inputs.nixpkgs.lib.nixosSystem
      {
        system = let arch.pi3b = "aarch64-linux"; in arch.${system} or "x86_64-linux";
        specialArgs = { topInputs = inputs; inherit localLib; };
        modules = localLib.mkModules
        [
          { config = { nixpkgs.overlays = [ inputs.self.overlays.default ]; nixos.model.hostname = system; }; }
          ../modules
          ../devices/${system}
          ../devices/cross
        ];
      };
    })
    machine)
  ++ (builtins.concatLists (builtins.map
    (cluster:
      let nodes = builtins.genList (n: "node${builtins.toString n}") cluster.value;
      in builtins.map
        (node:
        {
          name = "${cluster.name}-${node}";
          value = inputs.nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            specialArgs = { topInputs = inputs; inherit localLib; };
            modules = localLib.mkModules
            [
              {
                config =
                {
                  nixpkgs.overlays = [ inputs.self.overlays.default ];
                  nixos.model.cluster = { clusterName = cluster.name; nodeName = node; };
                };
              }
              ../modules
              ../devices/${cluster.name}
              ../devices/${cluster.name}/${node}
              ../devices/cross
            ];
          };
        })
        nodes)
    (localLib.attrsToList cluster)))
)
