inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./nix.nix
  ];
  options.nixos.system.nix = let inherit (inputs.lib) mkOption types; in
  {
    keepOutputs = mkOption { type = types.bool; default = false; };
    # null: use default substituters; not null: use specified substituters, default one is ignored
    substituters = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
  };
  config =
    let
      inherit (inputs.config.nixos) system;
    in
    {
      nix =
      {
        settings =
        {
          system-features = [ "big-parallel" "nixos-test" "benchmark" ];
          experimental-features = [ "nix-command" "flakes" ];
          keep-outputs = system.nix.keepOutputs;
          keep-failed = true;
          auto-optimise-store = true;
          substituters = if system.nix.substituters == null then [ "https://cache.nixos.org" ]
            else system.nix.substituters;
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
      systemd.services.nix-daemon =
      {
        serviceConfig = { CacheDirectory = "nix"; Slice = "-.slice"; Nice = "19"; };
        environment = { TMPDIR = "/var/cache/nix"; };
      };
    };
}
