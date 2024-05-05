# include <hpcstat/sql.hpp>
# include <hpcstat/ssh.hpp>
# include <hpcstat/env.hpp>
# include <hpcstat/keys.hpp>
# include <hpcstat/lfs.hpp>
# include <range/v3/view.hpp>
# include <boost/exception/diagnostic_information.hpp>

int main(int argc, const char** argv)
{
  try
  {
    using namespace hpcstat;
    using namespace std::literals;
    std::vector<std::string> args(argv, argv + argc);

    if (args.size() == 1)
      { std::cout << "Usage: hpcstat initdb|login|logout|submitjob|finishjob|verify|export\n"; return 1; }
    else if (args[1] == "initdb") { if (!sql::initdb()) { std::cerr << "Failed to initialize database\n"; return 1; } }
    else if (args[1] == "login")
    {
      if (env::interactive())
        { std::cout << "Communicating with the agent..." << std::flush; std::this_thread::sleep_for(1s); }
      if (auto fp = ssh::fingerprint(); !fp) return 1;
      else if (auto session = env::env("XDG_SESSION_ID", true); !session)
        return 1;
      else
      {
        sql::LoginData data
        {
          .Time = now(), .Key = *fp, .SessionId = *session, .Subaccount = env::env("HPCSTAT_SUBACCOUNT"),
          .Ip = env::env("SSH_CONNECTION"), .Interactive = env::interactive()
        };
        auto signature = ssh::sign(sql::serialize(data), *fp);
        if (!signature) return 1;
        data.Signature = *signature;
        sql::writedb(data);
        if (env::interactive())
          std::cout << fmt::format("\33[2K\rLogged in as {} (fingerprint: SHA256:{}).\n", Keys[*fp].Username, *fp);
      }
    }
    else if (args[1] == "logout")
    {
      if (auto session_id = env::env("XDG_SESSION_ID", true); !session_id)
        return 1;
      else sql::writedb(sql::LogoutData{ .Time = now(), .SessionId = *session_id });
    }
    else if (args[1] == "submitjob")
    {
      if (args.size() < 3) { std::cerr << "Usage: hpcstat submitjob <args passed to bsub>\n"; return 1; }
      if (auto fp = ssh::fingerprint(); !fp) return 1;
      else if (auto session = env::env("XDG_SESSION_ID", true); !session)
        return 1;
      else if
        (auto bsub = lfs::bsub(args | ranges::views::drop(2) | ranges::to<std::vector<std::string>>); !bsub)
        return 1;
      else
      {
        sql::SubmitJobData data
        {
          .Time = now(), .JobId = bsub->first, .Key = *fp, .SessionId = *session,
          .SubmitDir = std::filesystem::current_path().string(),
          .JobCommand = args | ranges::views::drop(2) | ranges::views::join(' ') | ranges::to<std::string>(),
          .Subaccount = env::env("HPCSTAT_SUBACCOUNT"), .Ip = env::env("SSH_CONNECTION")
        };
        auto signature = ssh::sign(sql::serialize(data), *fp);
        if (!signature) return 1;
        data.Signature = *signature;
        sql::writedb(data);
        std::cout << fmt::format
          ("Job <{}> was submitted to <{}> by <{}>.\n", bsub->first, bsub->second, Keys[*fp].Username);
      }
    }
    else if (args[1] == "finishjob")
    {
      if (auto fp = ssh::fingerprint(); !fp) return 1;
      else if (auto session = env::env("XDG_SESSION_ID", true); !session)
        return 1;
      else if (auto all_jobs = lfs::bjobs_list(); !all_jobs) return 1;
      else if
      (
        auto not_recorded = sql::finishjob_remove_existed
        (
          *all_jobs
            | ranges::views::transform([](auto& it) { return std::pair{ it.first, std::get<0>(it.second) }; })
            | ranges::to<std::map<unsigned, std::string>>
        );
        !not_recorded
      )
        return 1;
      else for (auto jobid : *not_recorded)
      {
        if (auto detail = lfs::bjobs_detail(jobid); !detail) return 1;
        else
        {
          sql::FinishJobData data
          {
            .Time = now(), .JobId = jobid, .JobResult = std::get<1>(all_jobs->at(jobid)),
            .SubmitTime = std::get<0>(all_jobs->at(jobid)), .JobDetail = *detail, .Key = *fp,
            .CpuTime = std::get<2>(all_jobs->at(jobid)),
          };
          if
          (
            auto signature = ssh::sign(sql::serialize(data), *fp);
            !signature
          )
            return 1;
          else { data.Signature = *signature; sql::writedb(data); }
        }
      }
    }
    else if (args[1] == "verify")
    {
      if (args.size() < 4) { std::cerr << "Usage: hpcstat verify <old.db> <new.db>\n"; return 1; }
      if (auto db_verify_result = sql::verify(args[2], args[3]); !db_verify_result) return 1;
      else for (auto& data : *db_verify_result)
        if (!std::apply(ssh::verify, data))
          { std::cerr << fmt::format("Failed to verify data: {}\n", std::get<0>(data)); return 1; }
    }
    else if (args[1] == "export")
    {
      if (args.size() < 4) { std::cerr << "Usage: hpcstat export <year> <month>\n"; return 1; }
      auto year_n = std::stoi(args[2]), month_n = std::stoi(args[3]);
      using namespace std::chrono;
      auto begin = sys_seconds(sys_days(month(month_n) / 1 / year_n)).time_since_epoch().count();
      auto end = sys_seconds(sys_days(month(month_n) / 1 / year_n + months(1)))
        .time_since_epoch().count();
      if 
      (
        !sql::export_data
          (begin, end, fmt::format("hpcstat-{}-{}.xlsx", year_n, month_n))
      )
        return 1;
    }
    else { std::cerr << "Unknown command.\n"; return 1; }
  }
  catch (...) { std::cerr << boost::current_exception_diagnostic_information() << std::endl; return 1; }
  return 0;
}
