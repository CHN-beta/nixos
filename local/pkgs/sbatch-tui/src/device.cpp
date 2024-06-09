# include <sbatch-tui/device.hpp>

Device_t Device
{
  .CpuMpiThreads = 1,
  .CpuOpenmpThreads = 1,
  .GpuIds = { "4060" }
};
