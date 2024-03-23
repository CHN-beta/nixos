inputs:
{
  options.nixos.services.slurm = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    cpu =
    {
      sockets = mkOption { type = types.ints.unsigned; default = 1; };
      cores = mkOption { type = types.ints.unsigned; };
      threads = mkOption { type = types.ints.unsigned; default = 1; };
    };
    memoryMB = mkOption { type = types.ints.unsigned; };
    gpus = mkOption { type = types.attrsOf types.ints.unsigned; };
  };
  config = let inherit (inputs.config.nixos.services) slurm; in inputs.lib.mkIf slurm.enable
  {
    services =
    {
      slurm =
      {
        server.enable = true;
        package = (inputs.pkgs.slurm.override { enableGtk2 = true; }).overrideAttrs
          (prev: let inherit (inputs.pkgs.cudaPackages) cuda_nvml_dev; in
          {
            buildInputs = prev.buildInputs ++ [ cuda_nvml_dev ];
            LDFLAGS = [ "-L${cuda_nvml_dev}/lib/stubs" ];
            nativeBuildInputs = prev.nativeBuildInputs ++ [ inputs.pkgs.wrapGAppsHook ];
            postInstall =
            ''
              pushd contribs/pmi2
              make install
              popd
            '' + prev.postInstall;
          });
        clusterName = inputs.config.nixos.system.networking.hostname;
        dbdserver =
        {
          enable = true;
          dbdHost = "localhost";
          storagePassFile = inputs.config.sops.secrets."slurm/db".path;
          extraConfig =
          ''
            StorageHost=*
            StorageLoc=slurm
          '';
        };
        client.enable = true;
        controlMachine = "localhost";
        nodeName =
          let gpuString = builtins.concatStringsSep "," (builtins.map
            (gpu: "gpu:${gpu.name}:${builtins.toString gpu.value}")
            (inputs.localLib.attrsToList slurm.gpus));
          in inputs.lib.singleton (builtins.concatStringsSep " "
          [
            "localhost"
            "RealMemory=${builtins.toString slurm.memoryMB}"
            "Sockets=${builtins.toString slurm.cpu.sockets}"
            "CoresPerSocket=${builtins.toString slurm.cpu.cores}"
            "ThreadsPerCore=${builtins.toString slurm.cpu.threads}"
            "Gres=${gpuString}"
            "State=UNKNOWN"
          ]);
        partitionName = [ "localhost Nodes=localhost Default=YES MaxTime=INFINITE State=UP" ];
        procTrackType = "proctrack/cgroup";
        extraConfig =
          let taskProlog =
          ''
            echo export CUDA_DEVICE_ORDER=PCI_BUS_ID
            echo export SLURM_THREADS_PER_CPU=${builtins.toString slurm.cpu.threads}
          '';
          in
          ''
            SelectType=select/cons_tres
            SelectTypeParameters=CR_Core
            GresTypes=gpu
            DefCpuPerGPU=1

            TaskProlog=${inputs.pkgs.writeShellScript "set_env" taskProlog}

            AccountingStorageType=accounting_storage/slurmdbd
            AccountingStorageHost=localhost
            AccountingStoreFlags=job_comment,job_env,job_extra,job_script

            JobCompType=jobcomp/filetxt
            JobCompLoc=/var/log/slurmctld/jobcomp.log

            SchedulerParameters=enable_user_top

            SlurmdDebug=debug2
          '';
        extraConfigPaths =
          let gpuString = builtins.concatStringsSep "\n" (builtins.map
            (gpu: "Name=gpu Type=${gpu.name} Count=${builtins.toString gpu.value}")
            (inputs.localLib.attrsToList slurm.gpus));
          in [(inputs.pkgs.writeTextDir "gres.conf" "AutoDetect=nvml\n${gpuString}")];
      };
      munge = { enable = true; password = inputs.config.sops.secrets."munge.key".path; };
    };
    systemd =
    {
      services.slurmd.environment =
      {
        CUDA_PATH = "${inputs.pkgs.cudatoolkit}";
        LD_LIBRARY_PATH = "${inputs.config.hardware.nvidia.package}/lib";
      };
      tmpfiles.rules = [ "d /var/log/slurmctld 700 slurm slurm" ];
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
        "slurm/db" = { owner = "slurm"; key = "mariadb/slurm"; };
      };
    };
    nixos.services.mariadb = { enable = true; instances.slurm = {}; };
  };
}
