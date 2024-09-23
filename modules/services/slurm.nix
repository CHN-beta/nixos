inputs:
{
  options.nixos.services.slurm = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    # 本机是否为控制节点，如果不是，填写控制节点的主机名
    master = mkOption { type = types.nonEmptyStr; default = inputs.config.nixos.system.networking.hostname; };
    node = mkOption { type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      # slurm 中使用的节点名称
      name = mkOption { type = types.nonEmptyStr; };
      address = mkOption { type = types.nonEmptyStr; };
      cpu =
      {
        sockets = mkOption { type = types.ints.unsigned; default = 1; };
        cores = mkOption { type = types.ints.unsigned; default = 1; };
        threads = mkOption { type = types.ints.unsigned; default = 1; };
        mpiThreads = mkOption { type = types.ints.unsigned; default = 1; };
        openmpThreads = mkOption { type = types.ints.unsigned; default = 1; };
      };
      memoryMB = mkOption { type = types.ints.unsigned; default = 1024; };
      gpus = mkOption { type = types.nullOr (types.attrsOf types.ints.unsigned); default = null; };
    };}));};
    partitions = mkOption { type = types.attrsOf (types.listOf types.nonEmptyStr); default = {}; };
    defaultPartition = mkOption { type = types.nonEmptyStr; default = "localhost"; };
    tui =
    {
      cpuMpiThreads = mkOption { type = types.ints.unsigned; default = 1; };
      cpuOpenmpThreads = mkOption { type = types.ints.unsigned; default = 1; };
      gpus = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
    };
    # 是否打开防火墙相应端口，对于多节点部署需要打开
    setupFirewall = mkOption { type = types.bool; default = false; };
  };
  config = let inherit (inputs.config.nixos.services) slurm; in inputs.lib.mkIf slurm.enable (inputs.lib.mkMerge
  [
    # worker 配置
    {
      services =
      {
        slurm =
        {
          package = (inputs.pkgs.slurm.override { enableGtk2 = true; }).overrideAttrs
            (prev:
              let
                inherit (inputs.config.nixos.system.nixpkgs) cuda;
                inherit (inputs.pkgs.cudaPackages) cuda_nvml_dev;
                additionalInputs = inputs.lib.optionals cuda.enable [ cuda_nvml_dev cuda_nvml_dev.lib ];
                additionalFlags = inputs.lib.optional cuda.enable "-L${cuda_nvml_dev.lib}/lib/stubs";
              in
              {
                buildInputs = prev.buildInputs or [] ++ additionalInputs;
                LDFLAGS = prev.LDFLAGS or [] ++ additionalFlags;
                nativeBuildInputs = prev.nativeBuildInputs ++ [ inputs.pkgs.wrapGAppsHook ];
                postInstall =
                ''
                  pushd contribs/pmi2
                  make install
                  popd
                  pushd contribs/pmi
                  make install
                  popd
                '' + prev.postInstall;
              }
            );
          client.enable = true;
          nodeName = builtins.map
            (node:
              let gpuString =
                if node.value.gpus == null then ""
                else "Gres=" + builtins.concatStringsSep "," (builtins.map
                  (gpu: "gpu:${gpu.name}:${builtins.toString gpu.value}")
                  (inputs.lib.attrsToList node.value.gpus));
              in builtins.concatStringsSep " "
              [
                node.value.name
                "NodeHostname=${node.name}"
                "NodeAddr=${node.value.address}"
                "RealMemory=${builtins.toString node.value.memoryMB}"
                "Sockets=${builtins.toString node.value.cpu.sockets}"
                "CoresPerSocket=${builtins.toString node.value.cpu.cores}"
                "ThreadsPerCore=${builtins.toString node.value.cpu.threads}"
                "${gpuString}"
                "State=UNKNOWN"
              ])
            (inputs.localLib.attrsToList slurm.node);
          partitionName = builtins.map
            (partition:
              let nodes = builtins.concatStringsSep "," partition.value;
              in builtins.concatStringsSep " "
              [
                partition.name
                "Nodes=${builtins.concatStringsSep "," (builtins.map (n: slurm.node.${n}.name) partition.value)}"
                "Default=${if partition.name == slurm.defaultPartition then "YES" else "NO"}"
                "MaxTime=INFINITE"
                "State=UP"
              ])
            (inputs.localLib.attrsToList slurm.partitions);
          procTrackType = "proctrack/cgroup";
          controlMachine = slurm.master;
          controlAddr = slurm.node.${slurm.master}.address;
          extraConfig =
          ''
            SelectType=select/cons_tres
            SelectTypeParameters=CR_Core
            GresTypes=gpu
            DefCpuPerGPU=1

            TaskProlog=${inputs.pkgs.writeShellScript "set_env" "echo export CUDA_DEVICE_ORDER=PCI_BUS_ID"}

            AccountingStorageType=accounting_storage/slurmdbd
            AccountingStorageHost=localhost
            AccountingStoreFlags=job_comment,job_env,job_extra,job_script

            JobCompType=jobcomp/filetxt
            JobCompLoc=/var/log/slurmctld/jobcomp.log

            SchedulerParameters=enable_user_top

            SlurmdDebug=debug2
            DebugFlags=NO_CONF_HASH

            # automatically resume node after drain
            ReturnToService=2
          '';
          extraConfigPaths =
            let gpus = slurm.node.${inputs.config.nixos.system.networking.hostname}.gpus or null;
            in inputs.lib.mkIf (gpus != null)
            (
              let gpuString = builtins.concatStringsSep "\n" (builtins.map
                (gpu: "Name=gpu Type=${gpu.name} Count=${builtins.toString gpu.value}")
                (inputs.localLib.attrsToList gpus));
              in [(inputs.pkgs.writeTextDir "gres.conf" "AutoDetect=nvml\n${gpuString}")]
            );
        };
        munge = { enable = true; password = inputs.config.sops.secrets."munge.key".path; };
      };
      systemd =
      {
        services.slurmd.environment =
          let gpus = slurm.node.${inputs.config.nixos.system.networking.hostname}.gpus or null;
          in inputs.lib.mkIf (gpus != null)
          {
            CUDA_PATH = "${inputs.pkgs.cudatoolkit}";
            LD_LIBRARY_PATH = "${inputs.config.hardware.nvidia.package}/lib";
          };
      };
      sops.secrets."munge.key" =
      {
        format = "binary";
        sopsFile = "${builtins.dirOf inputs.config.sops.defaultSopsFile}/munge.key";
        owner = inputs.config.systemd.services.munged.serviceConfig.User;
      };
      networking.firewall =
        let config = inputs.lib.mkIf slurm.setupFirewall [ 6818 ];
        in { allowedTCPPorts = config; allowedUDPPorts = config; };
    }
    # master 配置
    (inputs.lib.mkIf (slurm.master == inputs.config.nixos.system.networking.hostname)
    {
      services.slurm =
      {
        server.enable = true;
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
      };
      systemd.tmpfiles.rules = [ "d /var/log/slurmctld 700 slurm slurm" ];
      sops.secrets."slurm/db" = { owner = "slurm"; key = "mariadb/slurm"; };
      nixos =
      {
        packages.packages._packages = [ inputs.pkgs.localPackages.sbatch-tui ];
        user.sharedModules = [{ home.packages =
        [
          (inputs.pkgs.writeShellScriptBin "sbatch"
          ''
            if [ "$#" -eq 0 ]; then
              sbatch-tui
            else
              /run/current-system/sw/bin/sbatch "$@"
            fi
          '')
        ];}];
        services.mariadb = { enable = true; instances.slurm = {}; };
      };
      environment.etc."sbatch-tui.yaml".text = builtins.toJSON
      {
        CpuMpiThreads = slurm.tui.cpuMpiThreads;
        CpuOpenmpThreads = slurm.tui.cpuOpenmpThreads;
        GpuIds = slurm.tui.gpus;
      };
      networking.firewall =
        let config = inputs.lib.mkIf slurm.setupFirewall [ 6817 ];
        in { allowedTCPPorts = config; allowedUDPPorts = config; };
    })
  ]);
}
