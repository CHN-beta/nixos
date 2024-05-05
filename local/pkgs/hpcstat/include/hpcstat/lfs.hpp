# pragma once
# include <optional>
# include <utility>
# include <string>
# include <vector>
# include <map>

namespace hpcstat::lfs
{
  std::optional<std::pair<unsigned, std::string>> bsub(std::vector<std::string> args);
  // JobId -> { SubmitTime, Status, CpuTime }
  std::optional<std::map<unsigned, std::tuple<std::string, std::string, double>>> bjobs_list();
  std::optional<std::string> bjobs_detail(unsigned jobid);
}
