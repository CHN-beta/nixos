{
  lib,
  config,
  self,
  ...
}:
{
  options.nixos.system.nix = {
    # marches allowed to be compiled on this machine
    marches = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = with config.nixos.system.nixpkgs; if march == null then [ ] else [ march ];
    };
    remote = {
      slave = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule { });
        default = null;
      };
      # host.[gcc arches]
      master.host = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.nonEmptyStr);
        default = { };
      };
    };
    githubToken.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.nixos.model.private;
    };
  };
  config =
    let
      inherit (config.nixos.system) nix;
    in
    lib.mkMerge [
      # general nix config
      {
        nix.settings = {
          system-features = [
            "big-parallel"
            "nixos-test"
            "benchmark"
          ];
          experimental-features = [
            "nix-command"
            "flakes"
            "ca-derivations"
            "mounted-ssh-store"
            "pipe-operators"
          ];
          keep-failed = true;
          max-substitution-jobs = 4;
          trusted-public-keys = [
            "chn:Cc+nowW1LIpe1kyXOZmNaznFDiH1glXmpb4A+WD/DTE="
            # llm-agents
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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
          substituters = [
            "https://backup-store.chn.moe"
            "https://nix-store.chn.moe"
            # llm-agents
            "https://cache.numtide.com"
          ];
          build-dir = "/var/cache/nix";
          download-buffer-size = 524288000;
        };
      }
      # nix daemon use lower io/cpu priority
      {
        nix = {
          daemonIOSchedClass = "idle";
          daemonCPUSchedPolicy = "idle";
        };
      }
      # nix channel & nix flake registry
      {
        nix = {
          registry = {
            nixpkgs.flake = self.inputs.nixpkgs;
            nixos.flake = self;
          };
          nixPath = [ "nixpkgs=${self.inputs.nixpkgs}" ];
        };
        environment = {
          etc = {
            "channels/nixpkgs".source = self.inputs.nixpkgs.outPath;
            "nixos".source = self.outPath;
          };
          variables.COMMA_NIXPKGS_FLAKE = "nixpkgs";
        };
      }
      # marches
      { nix.settings.system-features = builtins.map (march: "gccarch-${march}") nix.marches; }
      # remote.slave
      (lib.mkIf (nix.remote.slave != null) {
        nix = {
          sshServe = {
            enable = true;
            keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdUiHbT1Vs++5L0OPaMtYG7Wa0ejbJs2KBZ4QAspM4n nix-ssh@pc"
            ];
            write = true;
            protocol = "ssh-ng";
          };
          settings.trusted-users = [ "nix-ssh" ];
        };
      })
      # remote.master
      (lib.mkIf (nix.remote.master.host != { }) {
        nix = {
          distributedBuilds = true;
          buildMachines = lib.mapAttrsToList (n: v: {
            hostName = n;
            protocol = "ssh-ng";
            systems = [ "x86_64-linux" ];
            sshUser = "nix-ssh";
            sshKey = config.nixos.system.sops.secrets."nix/remote".path;
            maxJobs = 1;
            mandatoryFeatures = [ "big-parallel" ];
            supportedFeatures = builtins.map (f: "gccarch-${f}") v;
          }) nix.remote.master.host;
        };
        nixos.system.sops.secrets."nix/remote" = { };
      })
      (lib.mkIf nix.githubToken.enable {
        nix.extraOptions = "!include ${config.nixos.system.sops.templates."nix-github.conf".path}";
        nixos.system.sops = {
          templates."nix-github.conf" = {
            content = "access-tokens = github.com=${config.nixos.system.sops.placeholder."github/token"}";
            mode = "0444";
          };
          secrets."github/token" = { };
        };
      })
      # c++ include path
      # environment.pathsToLink = [ "/include" ];
      # environment.variables.CPATH = "/run/current-system/sw/include";
      # environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
    ];
}
