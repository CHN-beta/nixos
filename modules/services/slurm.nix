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
    gpus = mkOption { type = types.ints.unsigned; };
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
          });
        clusterName = inputs.config.nixos.system.networking.hostname;
        # dbdserver =
        # {
        #   enable = true;
        #   dbdHost = "localhost";
        #   # storagePassFile
        #   # extraConfig
        # };
        client.enable = true;
        controlMachine = "localhost";
        nodeName = inputs.lib.singleton (builtins.concatStringsSep " "
        [
          "localhost"
          "RealMemory=${builtins.toString slurm.memoryMB}"
          "Sockets=1"
          "CoresPerSocket=${builtins.toString slurm.cpu.cores}"
          "ThreadsPerCore=${builtins.toString slurm.cpu.threads}"
          "Gres=gpu:${builtins.toString slurm.gpus}"
          "State=UNKNOWN"
        ]);
        partitionName = [ "localhost Nodes=localhost Default=YES MaxTime=INFINITE State=UP" ];
        procTrackType = "proctrack/cgroup";
        extraConfig =
        ''
          SelectType=select/cons_tres
          GresTypes=gpu
          SlurmdDebug=debug2
          TaskProlog=${inputs.pkgs.writeShellScript "set_cuda_env" "echo export CUDA_DEVICE_ORDER=PCI_BUS_ID"}
        '';
        extraConfigPaths = [(inputs.pkgs.writeTextDir "gres.conf" "AutoDetect=nvml")];
      };
      munge = { enable = true; password = inputs.config.sops.secrets."munge.key".path; };
    };
    systemd.services.slurmd.environment =
    {
      CUDA_PATH = "${inputs.pkgs.cudatoolkit}";
      LD_LIBRARY_PATH = "${inputs.config.hardware.nvidia.package}/lib";
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
