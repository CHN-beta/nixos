# include <sbatch-tui/device.hpp>

Device_t Device
{
  .CpuMpiThreads = 1,
  .CpuOpenMPThreads = 1,
  .GpuIds = { "4060" }
};
