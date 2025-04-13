{ inputs, localLib }:
let
  singles = [ "nas" "pc" "vps6" "vps7" "one" ];
  cluster = { srv1 = 3; srv2 = 2; };
  devices = builtins.listToAttrs
  (
    (builtins.map (n: { name = n; value.hostname = n; }) singles)
    ++ (builtins.concatLists (builtins.map
      (cluster: builtins.map
        (node: { name = "${cluster.name}-${node}"; value.cluster = { clusterName = cluster.name; nodeName = node; }; })
        (builtins.genList (n: "node${builtins.toString n}") cluster.value))
      (localLib.attrsToList cluster)))
  );
in builtins.mapAttrs
  (_: v: inputs.nixpkgs.lib.nixosSystem
  {
    system = "x86_64-linux";
    specialArgs = { topInputs = inputs; inherit localLib; };
    modules = localLib.mkModules [ { config.nixos.model = v; } ../modules ];
  })
  devices
