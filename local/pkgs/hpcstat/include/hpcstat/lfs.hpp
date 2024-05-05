# pragma once
# include <hpcstat/common.hpp>

namespace hpcstat::lfs
{
  std::optional<std::pair<unsigned, std::string>> bsub(std::vector<std::string> args);
  // JobId -> { SubmitTime, Status, CpuTime, JobName }
  std::optional<std::map<unsigned, std::tuple<std::string, std::string, double, std::string>>> bjobs_list();
  std::optional<std::string> bjobs_detail(unsigned jobid);
}
