{ inputs, localLib }:
builtins.listToAttrs
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
          {
            config =
            {
              nixpkgs.overlays = [ inputs.self.overlays.default ];
              nixos.system.networking.hostname = system;
            };
          }
          ../modules
          ../devices/${system}
        ];
      };
    })
    [ "nas" "pc" "pi3b" "surface" "vps4" "vps6" "vps7" "xmupc1" "xmupc2" ])
  ++ (builtins.map
    (node:
    {
      name = "srv1-${node}";
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
              nixos.system.cluster = { clusterName = "srv1"; nodeName = node; };
            };
          }
          ../modules
          ../devices/srv1
          ../devices/srv1/${node}
        ];
      };
    })
    [ "node0" "node1" "node3" ])
)
