inputs:
{
  options.nixos.system.nix = let inherit (inputs.lib) mkOption types; in
  {
    # marches allowed to be compiled on this machine
    marches = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    keepOutputs = mkOption { type = types.bool; default = false; };
    substituters = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    autoOptimiseStore = mkOption { type = types.bool; default = true; };
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
            auto-optimise-store = nix.autoOptimiseStore;
            substituters = if nix.substituters == null then [ "https://cache.nixos.org/" ] else nix.substituters;
            max-substitution-jobs = 1;
            trusted-public-keys = [ "chn:Cc+nowW1LIpe1kyXOZmNaznFDiH1glXmpb4A+WD/DTE=" ];
            show-trace = true;
            max-jobs = 1;
            cores = 0;
            keep-going = true;
          };
          daemonIOSchedClass = "idle";
          daemonCPUSchedPolicy = "idle";
          registry =
          {
            nixpkgs.flake = inputs.topInputs.nixpkgs;
            nixpkgs-unstable.flake = inputs.topInputs.nixpkgs-unstable;
            nixos.flake = inputs.topInputs.self;
          };
          nixPath = [ "nixpkgs=${inputs.topInputs.nixpkgs}" ];
        };
        systemd.services.nix-daemon =
        {
          serviceConfig = { CacheDirectory = "nix"; Slice = "-.slice"; Nice = "19"; };
          environment = { TMPDIR = "/var/cache/nix"; };
        };
        environment =
        {
          etc =
          {
            "channels/nixpkgs".source = inputs.topInputs.nixpkgs.outPath;
            "channels/nixpkgs-unstable".source = inputs.topInputs.nixpkgs-unstable.outPath;
            "nixos".source = inputs.topInputs.self.outPath;
          };
          variables.COMMA_NIXPKGS_FLAKE = "nixpkgs-unstable";
        };
        # environment.pathsToLink = [ "/include" ];
        # environment.variables.CPATH = "/run/current-system/sw/include";
        # environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
        # gui.enable
      };
}
