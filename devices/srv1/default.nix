inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        fileSystems = { swap = [ "/dev/mapper/swap" ]; rollingRootfs = {}; };
        kernel.variant = "xanmod-lts";
        gui.enable = true;
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        snapper.enable = true;
        sshd = {};
        smartd.enable = true;
        slurm =
        {
          enable = true;
          cpu = { cores = 16; threads = 2; mpiThreads = 2; openmpThreads = 4; };
          memoryMB = 90112;
        };
      };
      user.users = [ "chn" ];
    };
  };
}
