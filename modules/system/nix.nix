inputs:
{
  options.nixos.system.nix = let inherit (inputs.lib) mkOption types; in
  {
    # marches allowed to be compiled on this machine
    marches = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    includeBuildDependencies = mkOption { type = types.bool; default = inputs.topInputs.self.config.archive; };
    substituters = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    autoOptimiseStore = mkOption { type = types.bool; default = false; };
  };
  config = let inherit (inputs.config.nixos.system) nix; in inputs.lib.mkMerge
  [
    # general nix config
    {
      nix.settings =
      {
        system-features = [ "big-parallel" "nixos-test" "benchmark" ];
        experimental-features = [ "nix-command" "flakes" ];
        keep-failed = true;
        max-substitution-jobs = 4;
        trusted-public-keys = [ "chn:Cc+nowW1LIpe1kyXOZmNaznFDiH1glXmpb4A+WD/DTE=" ];
        show-trace = true;
        max-jobs = 4;
        cores = 0;
        keep-going = true;
        keep-outputs = true;
      };
      systemd.services.nix-daemon = { serviceConfig.CacheDirectory = "nix"; environment.TMPDIR = "/var/cache/nix"; };
    }
    # nix daemon use lower io/cpu priority
    {
      nix = { daemonIOSchedClass = "idle"; daemonCPUSchedPolicy = "idle"; };
      systemd.services.nix-daemon.serviceConfig = { Slice = "-.slice"; Nice = "19"; };
    }
    # nix channel & nix flake registry
    {
      nix =
      {
        registry =
        {
          nixpkgs.flake = inputs.topInputs.nixpkgs;
          nixpkgs-unstable.flake = inputs.topInputs.nixpkgs-unstable;
          nixos.flake = inputs.topInputs.self;
        };
        nixPath = [ "nixpkgs=${inputs.topInputs.nixpkgs}" ];
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
    }
    # marches
    {
      nix.settings.system-features =
      (map
        (march: "gccarch-${march}")
        (
          if nix.marches == null then
            (with inputs.config.nixos.system.nixpkgs; if march == null then [] else [ march ])
          else nix.marches
        ))
      ++ (with inputs.config.nixos.system.nixpkgs; if march == null then [] else [ "nvhpcArch-${march}" ]);
    }
    # includeBuildDependencies
    {
      system.includeBuildDependencies = nix.includeBuildDependencies;
    }
    # substituters
    {
      nix.settings.substituters = if nix.substituters == null then [ "https://cache.nixos.org/" ] else nix.substituters;
    }
    # autoOptimiseStore
    {
      nix.settings.auto-optimise-store = nix.autoOptimiseStore;
    }
    # c++ include path
    # environment.pathsToLink = [ "/include" ];
    # environment.variables.CPATH = "/run/current-system/sw/include";
    # environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
  ];
}
