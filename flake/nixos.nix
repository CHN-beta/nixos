{ inputs, devices, localLib }:
builtins.listToAttrs (builtins.map
  (system:
  {
    name = system;
    value = inputs.nixpkgs.lib.nixosSystem
    {
      system = let arch.pi3b = "aarch64-linux"; in arch.${system} or "x86_64-linux";
      specialArgs = { topInputs = inputs; inherit localLib; };
      modules = localLib.mkModules
      [
        { config.nixpkgs.overlays = [ inputs.self.overlays.default ]; }
        ../modules
        ../devices/${system}
      ];
    };
  })
  devices)
