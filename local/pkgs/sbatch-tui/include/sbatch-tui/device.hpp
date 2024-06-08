# pragma once
# include <string>
# include <vector>

struct Device_t
{
  unsigned CpuMpiThreads, CpuOpenMPThreads;
  std::vector<std::string> GpuIds;
};
extern Device_t Device;
