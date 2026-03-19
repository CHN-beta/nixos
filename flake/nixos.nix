{ inputs, localLib }:
let
  inherit (inputs.nixpkgs) lib;
  singles = [ "nas" "pc" "vps4" "vps6" "vps9" ];
  cluster = { srv1 = 3; srv2 = 3; };
  deviceModules = builtins.listToAttrs
  (
    (builtins.map
      (n: { name = n; value = [ { config.nixos.model.hostname = n; } ../modules ../devices/${n} ../devices/cross ]; })
      singles)
    ++ (builtins.concatLists (builtins.map
      (cluster: builtins.map
        (node:
        {
          name = "${cluster.name}-${node}";
          value =
          [
            { config.nixos.model.cluster = { clusterName = cluster.name; nodeName = node; }; }
            ../modules
            ../devices/${cluster.name}
            ../devices/${cluster.name}/${node}
            ../devices/cross
          ];
        })
        (builtins.genList (n: "node${builtins.toString n}") cluster.value))
      (lib.attrsToList cluster)))
  );
in builtins.mapAttrs
  (n: v: lib.nixosSystem
  {
    system = null;
    specialArgs = { topInputs = inputs; inherit localLib; };
    modules = localLib.mkModules v;
  })
  deviceModules
