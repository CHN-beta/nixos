inputs:
{
  options.nixos.system.nix = let inherit (inputs.lib) mkOption types; in
  {
    # marches allowed to be compiled on this machine
    marches = mkOption
    {
      type = types.listOf types.nonEmptyStr;
      default = with inputs.config.nixos.system.nixpkgs; if march == null then [] else [ march ];
    };
    remote =
    {
      slave = mkOption { type = types.nullOr (types.submodule {}); default = null; };
      # host.[gcc arches]
      master.host = mkOption { type = types.attrsOf (types.listOf types.nonEmptyStr); default = {}; };
    };
    githubToken.enable = mkOption { type = types.bool; default = inputs.config.nixos.model.private; };
  };
  config = let inherit (inputs.config.nixos.system) nix; in inputs.lib.mkMerge
  [
    # general nix config
    {
      nix.settings =
      {
        system-features = [ "big-parallel" "nixos-test" "benchmark" ];
        experimental-features = [ "nix-command" "flakes" "ca-derivations" "mounted-ssh-store" ];
        keep-failed = true;
        max-substitution-jobs = 4;
        trusted-public-keys =
        [
          "chn:Cc+nowW1LIpe1kyXOZmNaznFDiH1glXmpb4A+WD/DTE="
          "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA="
        ];
        trusted-users = [ "@wheel" ];
        show-trace = true;
        max-jobs = 4;
        cores = 0;
        keep-going = true;
        # do not keep unused outputs, backup it manually on nas
        keep-outputs = false;
        connect-timeout = 5;
        # https://cache.nixos.org 已经自带
        substituters = [ "https://nix-store.chn.moe" ];
        build-dir = "/var/cache/nix";
      };
    }
    # nix daemon use lower io/cpu priority
    { nix = { daemonIOSchedClass = "idle"; daemonCPUSchedPolicy = "idle"; }; }
    # nix channel & nix flake registry
    {
      nix =
      {
        registry =
        {
          nixpkgs.flake = inputs.flakeInputs.nixpkgs;
          nixos.flake = inputs.flakeInputs.self;
          nixpkgs-unstable.flake = inputs.flakeInputs.nixpkgs-unstable;
        };
        nixPath = [ "nixpkgs=${inputs.flakeInputs.nixpkgs}" ];
      };
      environment =
      {
        etc =
        {
          "channels/nixpkgs".source = inputs.flakeInputs.nixpkgs.outPath;
          "nixos".source = inputs.flakeInputs.self.outPath;
        };
        variables.COMMA_NIXPKGS_FLAKE = "nixpkgs-unstable";
      };
    }
    # marches
    { nix.settings.system-features = builtins.map (march: "gccarch-${march}") nix.marches; }
    # remote.slave
    (inputs.lib.mkIf (nix.remote.slave != null)
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
    (inputs.lib.mkIf (nix.remote.master.host != {})
    {
      nix =
      {
        distributedBuilds = true;
        buildMachines = inputs.lib.mapAttrsToList
          (n: v:
          {
            hostName = n;
            protocol = "ssh-ng";
            systems = [ "x86_64-linux" ];
            sshUser = "nix-ssh";
            sshKey = inputs.config.nixos.system.sops.secrets."nix/remote".path;
            maxJobs = 1;
            mandatoryFeatures = [ "big-parallel" ];
            supportedFeatures = builtins.map (f: "gccarch-${f}") v;
          })
          nix.remote.master.host;
      };
      nixos.system.sops.secrets."nix/remote" = {};
    })
    (inputs.lib.mkIf nix.githubToken.enable
    {
      nix.extraOptions = "!include ${inputs.config.nixos.system.sops.templates."nix-github.conf".path}";
      nixos.system.sops =
      {
        templates."nix-github.conf" =
        {
          content = "access-tokens = github.com=${inputs.config.nixos.system.sops.placeholder."github/token"}";
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
