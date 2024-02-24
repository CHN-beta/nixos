inputs:
{
  options.nixos.services.slurm = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    cpu =
    {
      cores = mkOption { type = types.ints.unsigned; };
      threads = mkOption { type = types.ints.unsigned; default = 1; };
    };
    memoryMB = mkOption { type = types.ints.unsigned; };
  };
  config = let inherit (inputs.config.nixos.services) slurm; in inputs.lib.mkIf slurm.enable
  {
    services =
    {
      slurm =
      {
        server.enable = true;
        clusterName = inputs.config.nixos.system.networking.hostname;
        # dbdserver =
        # {
        #   enable = true;
        #   dbdHost = "localhost";
        #   # storagePassFile
        #   # extraConfig
        # };
        client.enable = true;
        # package
        controlMachine = "localhost";
        nodeName = inputs.lib.singleton (builtins.concatStringsSep " "
        [
          "localhost"
          "RealMemory=${builtins.toString slurm.memoryMB}"
          "Sockets=1"
          "CoresPerSocket=${builtins.toString slurm.cpu.cores}"
          "ThreadsPerCore=${builtins.toString slurm.cpu.threads}"
          "State=UNKNOWN"
        ]);
        partitionName = [ "localhost Nodes=localhost Default=YES MaxTime=INFINITE State=UP" ];
        procTrackType = "proctrack/cgroup";
      };
      munge = { enable = true; password = inputs.config.sops.secrets."munge.key".path; };
    };
    sops =
    {
      secrets =
      {
        "munge.key" =
        {
          format = "binary";
          sopsFile = "${builtins.dirOf inputs.config.sops.defaultSopsFile}/munge.key";
          owner = inputs.config.systemd.services.munged.serviceConfig.User;
        };
      };
    };
  };
}
