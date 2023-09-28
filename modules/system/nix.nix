inputs:
{
  options.nixos.system.nix = let inherit (inputs.lib) mkOption types; in
  {
    # marches allowed to be compiled on this machine
    marches = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    keepOutputs = mkOption { type = types.bool; default = false; };
    substituters = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
  };
  config =
    let
      inherit (inputs.config.nixos.system) nix;
    in
      {
        nix =
        {
          settings =
          {
            system-features = [ "big-parallel" "nixos-test" "benchmark" ] ++ (map
              (march: "gccarch-${march}")
              (
                if nix.marches == null then
                  (with inputs.config.nixos.system.nixpkgs; if march == null then [] else [ march ])
                else nix.marches
              ));
            experimental-features = [ "nix-command" "flakes" ];
            keep-outputs = nix.keepOutputs;
            keep-failed = true;
            substituters = if nix.substituters == null then [ "https://cache.nixos.org/" ] else nix.substituters;
            trusted-public-keys = [ "chn:Cc+nowW1LIpe1kyXOZmNaznFDiH1glXmpb4A+WD/DTE=" ];
            show-trace = true;
            max-jobs = 2;
            cores = 0;
            keep-going = true;
          };
          daemonIOSchedClass = "idle";
          daemonCPUSchedPolicy = "idle";
          registry =
          {
            nixpkgs.flake = inputs.topInputs.nixpkgs;
            nixos.flake = inputs.topInputs.self;
          };
          nixPath = [ "nixpkgs=${inputs.topInputs.nixpkgs}" ];
        };
        system =
        {
          stateVersion = "22.11";
          configurationRevision = inputs.topInputs.self.rev or "dirty";
        };
        systemd.services.nix-daemon =
        {
          serviceConfig = { CacheDirectory = "nix"; Slice = "-.slice"; Nice = "19"; };
          environment = { TMPDIR = "/var/cache/nix"; };
        };
        environment.etc =
        {
          "channels/nixpkgs".source = inputs.topInputs.nixpkgs.outPath;
          "nixos".source = inputs.topInputs.self.outPath;
        };
        # environment.pathsToLink = [ "/include" ];
        # environment.variables.CPATH = "/run/current-system/sw/include";
        # environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
        # gui.enable
      };
}
