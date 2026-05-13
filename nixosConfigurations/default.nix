self:
let
  inherit (self.inputs.nixpkgs) lib;
  singles = [ "nas" "pc" "vps4" "vps6" "vps9" "pe" ];
  cluster = { srv1 = 3; srv2 = 3; };
  deviceModules =
    [
      (singles |> lib.flip lib.genAttrs (n: [ { config.nixos.model.hostname = n; } ./${n}.nix ]))
      (cluster
        |> lib.mapAttrsToList (n: v: lib.genList (i: "node${builtins.toString i}") v
          |> lib.flip lib.genAttrs' (node: lib.nameValuePair "${n}-${node}"
            [ { config.nixos.model.cluster = { clusterName = n; nodeName = node; }; } ./${n} ./${n}/${node}.nix ]))
        |> lib.mergeAttrsList)
    ]
    |> lib.mergeAttrsList;
in deviceModules
  |> builtins.mapAttrs
    (n: v: lib.nixosSystem
    {
      system = null;
      specialArgs = { flakeInputs = self.inputs; localLib = self.lib; inherit self; };
      modules = (self.lib.mkModules v) ++ [ self.nixosModules.default ];
    })
