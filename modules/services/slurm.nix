{ lib, config, pkgs, flakeInputs, localLib, ... }:
{
  options.nixos.services.slurm = let inherit (lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    # 本机是否为控制节点，如果不是，填写控制节点的主机名
    master = mkOption { type = types.nonEmptyStr; default = config.nixos.model.hostname; };
    node = mkOption { type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      # slurm 中使用的节点名称
      name = mkOption { type = types.nonEmptyStr; };
      address = mkOption { type = types.nonEmptyStr; };
      cpu =
      {
        sockets = mkOption { type = types.ints.unsigned; default = 1; };
        cores = mkOption { type = types.ints.unsigned; };
        threads = mkOption { type = types.ints.unsigned; default = 1; };
      };
      memoryGB = mkOption { type = types.ints.unsigned; };
      gpus = mkOption { type = types.nullOr (types.attrsOf types.ints.unsigned); default = null; };
    };}));};
    partitions = mkOption { type = types.attrsOf (types.listOf types.nonEmptyStr); default = {}; };
    defaultPartition = mkOption { type = types.nonEmptyStr; default = "localhost"; };
    tui =
    {
      cpuQueues = mkOption
      {
        type = types.nonEmptyListOf (types.submodule (submoduleInputs: { options =
        {
          name = mkOption { type = types.nonEmptyStr; default = "localhost"; };
          mpiThreads = mkOption { type = types.ints.unsigned; default = 1; };
          openmpThreads = mkOption { type = types.ints.unsigned; default = 1; };
          memoryGB = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
          allocateCpus = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
        };}));
      };
      gpuQueues = mkOption
      {
        type = types.nullOr (types.nonEmptyListOf (types.submodule (submoduleInputs: { options =
        {
          name = mkOption { type = types.nonEmptyStr; default = "localhost"; };
          gpuIds = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
        };})));
        default = null;
      };
    };
  };
  config = let inherit (config.nixos.services) slurm; in lib.mkIf slurm.enable
  (
    let info = pkgs.localPackages.info.override
    {
      slurm = config.services.slurm.package;
      configFile = config.nixos.system.sops.templates."info.yaml".path;
    };
    in lib.mkMerge
    [
      # worker 配置
      {
        services =
        {
          slurm =
          {
            package = (pkgs.slurm.override { enableX11 = false; }).overrideAttrs (prev:
            {
              postInstall =
              ''
                pushd contribs/pmi2
                make install
                popd
                pushd contribs/pmi
                make install
                popd
              '' + prev.postInstall;
            });
            client.enable = true;
            nodeName = builtins.map
              (node:
                let gpuString =
                  if node.value.gpus == null then ""
                  else "Gres=" + builtins.concatStringsSep "," (builtins.map
                    (gpu: "gpu:${gpu.name}:${builtins.toString gpu.value}")
                    (lib.attrsToList node.value.gpus));
                in builtins.concatStringsSep " "
                [
                  node.value.name
                  "NodeHostname=${node.name}"
                  "NodeAddr=${node.value.address}"
                  "RealMemory=${builtins.toString (node.value.memoryGB * 1024)}"
                  "Sockets=${builtins.toString node.value.cpu.sockets}"
                  "CoresPerSocket=${builtins.toString node.value.cpu.cores}"
                  "ThreadsPerCore=${builtins.toString node.value.cpu.threads}"
                  "${gpuString}"
                  "State=UNKNOWN"
                ])
              (lib.attrsToList slurm.node);
            partitionName = lib.mapAttrsToList
              (n: v: builtins.concatStringsSep " "
              [
                n
                "Nodes=${builtins.concatStringsSep "," (builtins.map (n: slurm.node.${n}.name) v)}"
                "Default=${if n == slurm.defaultPartition then "YES" else "NO"}"
                "DefaultTime=48:00:00"
                "State=UP"
                ''TRESBillingWeights="CPU=1.0,Mem=0.1G,GRES/gpu=10"''
              ])
              slurm.partitions;
            procTrackType = "proctrack/cgroup";
            controlMachine = slurm.master;
            controlAddr = slurm.node.${slurm.master}.address;
            extraConfig =
            ''
              SelectType=select/cons_tres
              SelectTypeParameters=CR_Core_Memory
              GresTypes=gpu

              TaskProlog=${pkgs.writeShellScript "set_env" "echo export CUDA_DEVICE_ORDER=PCI_BUS_ID"}

              AccountingStorageType=accounting_storage/slurmdbd
              AccountingStorageHost=localhost
              AccountingStoreFlags=job_comment,job_env,job_extra,job_script

              JobCompType=jobcomp/filetxt
              JobCompLoc=/var/log/slurmctld/jobcomp.log

              # bf_xxx: backfill scheduler, set these to disable reservation of resources for high priority jobs
              SchedulerParameters=enable_user_top,bf_window=10,bf_min_age_reserve=2592000,bf_min_prio_reserve=9223372036854775808

              SlurmdDebug=debug2
              SlurmdParameters=l3cache_as_socket
              DebugFlags=NO_CONF_HASH,CPU_Bind,Gres

              # automatically resume node after drain
              ReturnToService=2

              # enable task plugins
              TaskPlugin=task/affinity,task/cgroup

              # omit --mpi=pmix
              MpiDefault=pmix

              # record more info
              JobAcctGatherType=jobacct_gather/cgroup
              AccountingStorageTRES=gres/gpu
              PrologFlags=contain

              # append to output file
              JobFileAppend=1

              # correctly set priority
              PriorityType=priority/multifactor
              PriorityWeightAge=10000
              PriorityWeightFairshare=100000
              AccountingStorageEnforce=associations

              # use low resource as default
              DefCpuPerGPU=1
              DefMemPerCPU=1024

              # Sometimes (especially with io intensive job), slurmd may fail to kill job, leading to node drain
              #   with reason: kill task failed. This might mitigate the issue.
              # wait for 5 minutes after sending SIGTERM before sending SIGKILL (default is 30 seconds)
              KillWait = 300
              # if task cannot be stopped after another 5 minutes (default 1 minute), notify admin
              UnkillableStepTimeout = 600
              UnkillableStepProgram = ${info}/bin/kill-failed
              # allow 1 minute delay for slurmd and slurmctld to communicate (default is 10 seconds)
              MessageTimeout = 60
            '';
            extraConfigPaths =
              let gpus = slurm.node.${config.nixos.model.hostname}.gpus or null;
              in lib.mkIf (gpus != null)
              (
                let gpuString = builtins.concatStringsSep "\n" (builtins.map
                  (gpu: "Name=gpu Type=${gpu.name} Count=${builtins.toString gpu.value}")
                  (lib.attrsToList gpus));
                in [(pkgs.writeTextDir "gres.conf" "AutoDetect=nvml\n${gpuString}")]
              );
            extraCgroupConfig =
            ''
              ConstrainCores=yes
              ConstrainRAMSpace=yes
              ConstrainSwapSpace=yes
              AllowedSwapSpace=20
              # this make job hang, not sure why
              # ConstrainDevices=yes
            '';
            extraPlugstackConfig =
            ''
              required ${info}/lib/libinfo-spank.so
            '';
          };
          munge = { enable = true; password = config.nixos.system.sops.secrets."munge.key".path; };
        };
        systemd.services.slurmd.environment =
          let gpus = slurm.node.${config.nixos.model.hostname}.gpus or null;
          in lib.mkIf (gpus != null)
          {
            CUDA_PATH = "${pkgs.cudatoolkit}";
            LD_LIBRARY_PATH = "${config.hardware.nvidia.package}/lib";
          };
        nixos.system.sops =
        {
          secrets =
          {
            "munge.key" =
            {
              format = "binary";
              sopsFile =
                let
                  devicePath = "${flakeInputs.self}/devices";
                  inherit (config.nixos) model;
                in localLib.mkConditional (model.cluster == null)
                  "${devicePath}/${model.hostname}/secrets/munge.key"
                  "${devicePath}/${model.cluster.clusterName}/secrets/munge.key";
              owner = config.systemd.services.munged.serviceConfig.User;
            };
          }
          // builtins.listToAttrs (builtins.map
            (n: lib.nameValuePair "telegram/${n}" {})
            [ "token" "user/chn" "user/hjp" "user/root" ]);
          templates."info.yaml" =
          {
            owner = "slurm";
            content = let inherit (config.nixos.system.sops) placeholder; in builtins.toJSON
            {
              token = placeholder."telegram/token";
              user =  builtins.listToAttrs (builtins.map
                (n: lib.nameValuePair n placeholder."telegram/user/${n}") [ "chn" "hjp" "root" ]);
              slurmConf = "${config.services.slurm.etcSlurm}/slurm.conf";
            };
          };
        };
        environment.sessionVariables = { SLURM_UNBUFFEREDIO = "1"; SLURM_CPU_BIND = "v"; };
      }
      # master 配置
      (lib.mkIf (slurm.master == config.nixos.model.hostname)
      {
        services.slurm =
        {
          server = { enable = true; flag.i = true; };
          dbdserver =
          {
            enable = true;
            dbdHost = "localhost";
            storagePassFile = config.nixos.system.sops.secrets."slurm/db".path;
            extraConfig =
            ''
              StorageHost=*
              StorageLoc=slurm
            '';
          };
          extraConfig =
          ''
            PrologSlurmctld=${config.security.wrapperDir}/slurm-info
            EpilogSlurmctld=${config.security.wrapperDir}/slurm-info
          '';
        };
        systemd =
        {
          services =
          {
            slurmctld =
            {
              after = [ "suid-sgid-wrappers.service" "slurmdbd.service" ];
              serviceConfig =
              {
                # never swap
                MemorySwapMax = "0";
                # highest priority
                CPUSchedulingPolicy = "fifo";
                CPUSchedulingPriority = "99";
                IOSchedulingClass = "realtime";
                IOSchedulingPriority = "0";
              };
            };
            slurmdbd.postStart = builtins.concatStringsSep "\n" (builtins.concatLists
            [
              [ "until sacctmgr ping; do sleep 1; done" ]
              (builtins.map
                (user: ''sacctmgr -i add user name="${user}" Account=root DefaultAccount=root || true'')
                config.nixos.user.users)
            ]);
          };
          tmpfiles.rules = [ "d /var/log/slurmctld 700 slurm slurm" ];
        };
        nixos.system.sops.secrets."slurm/db" = { owner = "slurm"; key = "mariadb/slurm"; };
        security.wrappers.info =
        {
          source = "${info}/bin/info";
          program = "slurm-info";
          owner = "slurm";
          group = "slurm";
          permissions = "544";
          capabilities = "cap_setuid,cap_setgid+ep";
        };
        nixos =
        {
          packages.packages._packages = [(pkgs.localPackages.sbatch-tui.override
          {
            sbatchConfig = pkgs.writeText "sbatch.yaml" (builtins.toJSON
            ({
              Program =
              {
                VaspCpu.Queue = builtins.map
                  (queue:
                  {
                    Name = queue.name;
                    Recommended =
                    {
                      Mpi = queue.mpiThreads;
                      Openmp = queue.openmpThreads;
                      Memory = queue.memoryGB;
                      Cpus = queue.allocateCpus;
                    };
                  })
                  slurm.tui.cpuQueues;
                Fdtd.Queue = builtins.map
                  (queue:
                  {
                    Name = queue.name;
                    Recommended =
                    {
                      Cpus =
                        if queue.allocateCpus != null then queue.allocateCpus
                        else queue.mpiThreads * queue.openmpThreads;
                      Memory = queue.memoryGB;
                    };
                  })
                  slurm.tui.cpuQueues;
              }
              // (if slurm.tui.gpuQueues == null then {} else rec
              {
                VaspGpu.Queue = builtins.map (queue: { Name = queue.name; Gpu = queue.gpuIds; }) slurm.tui.gpuQueues;
                Mumax3 = VaspGpu;
              });
            }));
          })];
          user.sharedModules = [{ home.packages =
          [
            (pkgs.writeShellScriptBin "sbatch"
              ''if [ "$#" -eq 0 ]; then sbatch-tui; else /run/current-system/sw/bin/sbatch "$@"; fi'')
          ];}];
          services.mariadb = { enable = true; instances.slurm = {}; };
        };
      })
    ]);
}
