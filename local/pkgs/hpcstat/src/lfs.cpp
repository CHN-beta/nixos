# include <hpcstat/lfs.hpp>
# include <hpcstat/env.hpp>
# include <nlohmann/json.hpp>

namespace hpcstat::lfs
{
  std::optional<std::pair<unsigned, std::string>> bsub(std::vector<std::string> args)
  {
    if (auto bsub = env::env("HPCSTAT_BSUB", true); !bsub)
      return std::nullopt;
    else
    {
      std::set<std::string> valid_args = { "J", "q", "n", "R", "o", "e", "c" };
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
      if (auto result = biu::exec(*bsub, args); !result) return std::nullopt;
      else
      {
        // Job <462270> is submitted to queue <normal_1day>.
        std::regex re(R"r(Job <(\d+)> is submitted to queue <(\w+)>.)r");
        std::smatch match;
        if (std::regex_search(result.Stdout, match, re))
          return std::make_pair(std::stoi(match[1]), match[2]);
        else
        {
          std::cerr << fmt::format("Failed to parse job id from output: {}\n", result.Stdout);
          return std::nullopt;
        }
      }
    }
  }
  std::optional<std::map<unsigned, std::tuple<std::string, std::string, double, std::string>>> bjobs_list
    (bool finished_jobs_only)
  {
    if
    (
      auto result = biu::exec<{.SearchPath = true}>
      (
        "bjobs", { "-a", "-o", "jobid submit_time stat cpu_used job_name", "-json" },
        {}, { { "LSB_DISPLAY_YEAR", "Y" } }
      );
      !result
    )
      return std::nullopt;
    else
    {
      nlohmann::json j;
      try { j = nlohmann::json::parse(result.Stdout); }
      catch (nlohmann::json::parse_error& e)
      {
        std::cerr << fmt::format("Failed to parse bjobs output: {}\n", e.what());
        return std::nullopt;
      }
      std::map<unsigned, std::tuple<std::string, std::string, double, std::string>> jobs;
      for (auto& job : j["RECORDS"])
      {
        std::string status = job["STAT"];
        if (finished_jobs_only && !std::set<std::string>{ "DONE", "EXIT" }.contains(status)) continue;
        std::string cpu_used_str = job["CPU_USED"];
        double cpu_used = 0;
        if (!cpu_used_str.empty())
        {
          try { cpu_used = std::stof(cpu_used_str.substr(0, cpu_used_str.find(' '))); }
          catch (std::invalid_argument& e)
            { std::cerr << fmt::format("Failed to parse cpu used: {}\n", e.what()); return std::nullopt; }
        }
        jobs[std::stoi(job["JOBID"].get<std::string>())] =
          { job["SUBMIT_TIME"], status, cpu_used, job["JOB_NAME"] };
      }
      return jobs;
    }
  }
  std::optional<std::string> bjobs_detail(unsigned jobid)
  {
    if
    (
      auto result = biu::exec<{.SearchPath = true}>
        ("bjobs", { "-l", std::to_string(jobid) });
      !result
    )
      return std::nullopt;
    else return result.Stdout;
  }
}
