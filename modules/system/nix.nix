inputs:
{
  options.nixos.system.nix = let inherit (inputs.lib) mkOption types; in
  {
    # marches allowed to be compiled on this machine
    marches = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    includeBuildDependencies = mkOption { type = types.bool; default = inputs.topInputs.self.config.archive; };
    substituters = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    autoOptimiseStore = mkOption { type = types.bool; default = false; };
    remote =
    {
      slave =
      {
        enable = mkOption { type = types.bool; default = false; };
        mandatoryFeatures = mkOption
        {
          type = types.listOf types.nonEmptyStr;
          default = [ "gccarch-exact-${inputs.config.nixos.system.nixpkgs.march}" ];
        };
      };
      master =
      {
        enable = mkOption { type = types.bool; default = false; };
        hosts = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      };
    };
    githubToken.enable = mkOption { type = types.bool; default = false; };
  };
  config = let inherit (inputs.config.nixos.system) nix; in inputs.lib.mkMerge
  [
    # general nix config
    {
      nix.settings =
      {
        system-features = [ "big-parallel" "nixos-test" "benchmark" ];
        experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
        keep-failed = true;
        max-substitution-jobs = 4;
        trusted-public-keys = [ "chn:Cc+nowW1LIpe1kyXOZmNaznFDiH1glXmpb4A+WD/DTE=" ];
        trusted-users = [ "@wheel" ];
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
          nixos.flake = inputs.topInputs.self;
        };
        nixPath = [ "nixpkgs=${inputs.topInputs.nixpkgs}" ];
      };
      environment =
      {
        etc =
        {
          "channels/nixpkgs".source = inputs.topInputs.nixpkgs.outPath;
          "nixos".source = inputs.topInputs.self.outPath;
        };
        variables.COMMA_NIXPKGS_FLAKE = "nixpkgs";
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
      ++ (with inputs.config.nixos.system.nixpkgs; if march == null then [] else [ "gccarch-exact-${march}" ]);
    }
    # includeBuildDependencies
    (inputs.lib.mkIf nix.includeBuildDependencies
    {
      system.includeBuildDependencies = nix.includeBuildDependencies;
    })
    # substituters
    {
      nix.settings.substituters = if nix.substituters == null then [ "https://cache.nixos.org/" ] else nix.substituters;
    }
    # autoOptimiseStore
    (inputs.lib.mkIf nix.autoOptimiseStore
    {
      nix.settings.auto-optimise-store = nix.autoOptimiseStore;
    })
    # remote.slave
    (inputs.lib.mkIf nix.remote.slave.enable
    {
      nix =
      {
        sshServe =
        {
          enable = true;
          keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdUiHbT1Vs++5L0OPaMtYG7Wa0ejbJs2KBZ4QAspM4n nix-ssh@pc" ];
          write = true;
          protocol = "ssh-ng";
        };
        settings.trusted-users = [ "nix-ssh" ];
      };
    })
    # remote.master
    (inputs.lib.mkIf nix.remote.master.enable
    {
      assertions = builtins.map
        (host: 
        {
          assertion = inputs.topInputs.self.nixosConfigurations.${host}.config.nixos.system.nix.remote.slave.enable; 
          message = "remote.slave.enable is not set for ${host}";
        })
        nix.remote.master.hosts;
      nix =
      {
        distributedBuilds = true;
        buildMachines = builtins.map
          (host: let hostConfig = inputs.topInputs.self.nixosConfigurations.${host}.config; in
          {
            hostName = host;
            protocol = "ssh-ng";
            systems = [ "x86_64-linux" ] ++ hostConfig.nix.settings.extra-platforms;
            sshUser = "nix-ssh";
            sshKey = inputs.config.sops.secrets."nix/remote".path;
            maxJobs = 1;
            inherit (hostConfig.nixos.system.nix.remote.slave) mandatoryFeatures;
            supportedFeatures = hostConfig.nix.settings.system-features;
          })
          nix.remote.master.hosts;
      };
      sops.secrets."nix/remote" = {};
    })
    (inputs.lib.mkIf nix.githubToken.enable
    {
      nix.extraOptions = "!include ${inputs.config.sops.templates."nix-github.conf".path}";
      sops =
      {
        templates."nix-github.conf" =
        {
          content = "access-tokens = github.com=${inputs.config.sops.placeholder."github/token"}";
          mode = "0444";
        };
        secrets."github/token" = {};
      };
    })
    # c++ include path
    # environment.pathsToLink = [ "/include" ];
    # environment.variables.CPATH = "/run/current-system/sw/include";
    # environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
  ];
}
