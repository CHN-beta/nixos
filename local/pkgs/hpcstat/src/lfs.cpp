# include <regex>
# include <iostream>
# include <set>
# include <hpcstat/lfs.hpp>
# include <hpcstat/common.hpp>
# include <hpcstat/env.hpp>
# include <boost/process.hpp>
# include <fmt/format.h>
# include <nlohmann/json.hpp>

namespace hpcstat::lfs
{
  std::optional<std::pair<unsigned, std::string>> bsub(std::vector<std::string> args)
  {
    if (auto bsub = env::env("HPCSTAT_BSUB", true); !bsub)
      return std::nullopt;
    else
    {
      std::set<std::string> valid_args = { "J", "q", "n", "R", "o" };
      for (auto it = args.begin(); it != args.end(); ++it)
      {
        if (it->length() > 0 && (*it)[0] == '-')
        {
          if (!valid_args.contains(it->substr(1)))
          {
            std::cerr << fmt::format("Unknown bsub argument: {}\n", *it)
              << "bsub might support this argument, but hpcstat currently does not support it.\n"
                "If you are sure this argument is supported by bsub,\n"
                "please submit issue on [github](https://github.com/CHN-beta/hpcstat) or contact chn@chn.moe.\n";
            return std::nullopt;
          }
          else if (it + 1 != args.end() && ((it + 1)->length() == 0 || (*(it + 1))[0] != '-')) ++it;
        }
        else break;
      }
      if (auto result = exec(*bsub, args); !result) return std::nullopt;
      else
      {
        // Job <462270> is submitted to queue <normal_1day>.
        std::regex re(R"r(Job <(\d+)> is submitted to queue <(\w+)>.)r");
        std::smatch match;
        if (std::regex_search(*result, match, re))
          return std::make_pair(std::stoi(match[1]), match[2]);
        else
        {
          std::cerr << fmt::format("Failed to parse job id from output: {}\n", *result);
          return std::nullopt;
        }
      }
    }
  }
  std::optional<std::map<unsigned, std::tuple<std::string, std::string, double>>> bjobs_list()
  {
    if
    (
      auto result = exec
      (
        boost::process::search_path("bjobs").string(),
        { "-a", "-o", "jobid submit_time stat cpu_used", "-json" }
      );
      !result
    )
      return std::nullopt;
    else
    {
      nlohmann::json j;
      try { j = nlohmann::json::parse(*result); }
      catch (nlohmann::json::parse_error& e)
      {
        std::cerr << fmt::format("Failed to parse bjobs output: {}\n", e.what());
        return std::nullopt;
      }
      std::map<unsigned, std::tuple<std::string, std::string, double>> jobs;
      for (auto& job : j["RECORDS"])
      {
        std::string status = job["STAT"];
        if (!std::set<std::string>{ "DONE", "EXIT" }.contains(status)) continue;
        std::string submit_time = job["SUBMIT_TIME"];
        std::string cpu_used_str = job["CPU_USED"];
        double cpu_used = std::stof(cpu_used_str.substr(0, cpu_used_str.find(' ')));
        jobs[std::stoi(job["JOBID"].get<std::string>())] = { submit_time, status, cpu_used };
      }
      return jobs;
    }
  }
  std::optional<std::string> bjobs_detail(unsigned jobid)
  {
    if
    (
      auto result = exec
      (
        boost::process::search_path("bjobs").string(),
        { "-l", std::to_string(jobid) }
      );
      !result
    )
      return std::nullopt;
    else return *result;
  }
}
