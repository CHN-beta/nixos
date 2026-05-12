{ inputs, localLib }:
let
  inherit (inputs.nixpkgs) lib;
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
      specialArgs = { flakeInputs = inputs; inherit localLib; };
      modules = (localLib.mkModules v) ++ [ inputs.self.nixosModules.default ];
    })
