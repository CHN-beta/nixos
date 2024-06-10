# include <hpcstat/sql.hpp>
# include <hpcstat/env.hpp>
# include <hpcstat/keys.hpp>
# include <hpcstat/lfs.hpp>
# include <range/v3/range.hpp>
# include <range/v3/view.hpp>
# include <nameof.hpp>
# define SQLITE_ORM_OPTIONAL_SUPPORTED
# include <sqlite_orm/sqlite_orm.h>
# include <OpenXLSX.hpp>

namespace hpcstat::sql
{
  auto connect(std::optional<std::string> dbfile = std::nullopt)
  {
    auto conn = [&]() { return std::make_optional(sqlite_orm::make_storage
    (
      *dbfile,
      sqlite_orm::make_table
      (
        "login",
        sqlite_orm::make_column("id", &LoginData::Id, sqlite_orm::primary_key().autoincrement()),
        sqlite_orm::make_column("time", &LoginData::Time),
        sqlite_orm::make_column("key", &LoginData::Key),
        sqlite_orm::make_column("session_id", &LoginData::SessionId),
        sqlite_orm::make_column("signature", &LoginData::Signature),
        sqlite_orm::make_column("sub_account", &LoginData::Subaccount),
        sqlite_orm::make_column("ip", &LoginData::Ip),
        sqlite_orm::make_column("interactive", &LoginData::Interactive)
      ),
      sqlite_orm::make_table
      (
        "logout",
        sqlite_orm::make_column("id", &LogoutData::Id, sqlite_orm::primary_key().autoincrement()),
        sqlite_orm::make_column("time", &LogoutData::Time),
        sqlite_orm::make_column("session_id", &LogoutData::SessionId)
      ),
      sqlite_orm::make_table
      (
        "submit_job",
        sqlite_orm::make_column("id", &SubmitJobData::Id, sqlite_orm::primary_key().autoincrement()),
        sqlite_orm::make_column("time", &SubmitJobData::Time),
        sqlite_orm::make_column("job_id", &SubmitJobData::JobId),
        sqlite_orm::make_column("key", &SubmitJobData::Key),
        sqlite_orm::make_column("session_id", &SubmitJobData::SessionId),
        sqlite_orm::make_column("submit_dir", &SubmitJobData::SubmitDir),
        sqlite_orm::make_column("job_command", &SubmitJobData::JobCommand),
        sqlite_orm::make_column("signature", &SubmitJobData::Signature),
        sqlite_orm::make_column("sub_account", &SubmitJobData::Subaccount),
        sqlite_orm::make_column("ip", &SubmitJobData::Ip)
      ),
      sqlite_orm::make_table
      (
        "finish_job",
        sqlite_orm::make_column("id", &FinishJobData::Id, sqlite_orm::primary_key().autoincrement()),
        sqlite_orm::make_column("time", &FinishJobData::Time),
        sqlite_orm::make_column("job_id", &FinishJobData::JobId),
        sqlite_orm::make_column("job_result", &FinishJobData::JobResult),
        sqlite_orm::make_column("submit_time", &FinishJobData::SubmitTime),
        sqlite_orm::make_column("job_detail", &FinishJobData::JobDetail),
        sqlite_orm::make_column("key", &FinishJobData::Key),
        sqlite_orm::make_column("signature", &FinishJobData::Signature),
        sqlite_orm::make_column("cpu_time", &FinishJobData::CpuTime)
      ),
      sqlite_orm::make_table
      (
        "check_job",
        sqlite_orm::make_column("id", &CheckJobData::Id, sqlite_orm::primary_key().autoincrement()),
        sqlite_orm::make_column("job_id", &CheckJobData::JobId),
        sqlite_orm::make_column("status", &CheckJobData::Status)
      )
    ));};
    if (!dbfile)
    {
      if (auto datadir = env::env("HPCSTAT_DATADIR", true); !datadir)
        return decltype(conn())();
      else dbfile = std::filesystem::path(*datadir) / "hpcstat.db";
    }
    auto result = conn();
    if (!result) std::cerr << "Failed to connect to database.\n";
    else result->busy_timeout(10000);
    return result;
  }
  bool initdb()
  {
    if (auto conn = connect(); !conn) return false;
    else { conn->sync_schema(); return true; }
  }
  bool writedb(auto value)
    { if (auto conn = connect(); !conn) return false; else { conn->insert(value); return true; } }
  template bool writedb(LoginData);
  template bool writedb(LogoutData);
  template bool writedb(SubmitJobData);
  template bool writedb(FinishJobData);
  std::optional<std::set<unsigned>> finishjob_remove_existed(std::map<unsigned, std::string> jobid_submit_time)
  {
    if (auto conn = connect(); !conn) return std::nullopt;
    else
    {
      auto all_job = jobid_submit_time | ranges::views::keys | ranges::to<std::vector<unsigned>>;
      auto logged_job = conn->get_all<FinishJobData>
        (sqlite_orm::where(sqlite_orm::in(&FinishJobData::JobId, all_job)));
      auto not_logged_job = all_job | ranges::to<std::set<unsigned>>;
      for (auto it : logged_job)
        if (jobid_submit_time[it.JobId] == it.SubmitTime)
          not_logged_job.erase(it.JobId);
      return not_logged_job;
    }
  }
  std::optional<std::vector<std::tuple<std::string, std::string, std::string>>>
    verify(std::string old_db, std::string new_db)
  {
    auto old_conn = connect(old_db), new_conn = connect(new_db);
    if (!old_conn || !new_conn) { std::cerr << "Failed to connect to database.\n"; return std::nullopt; }
    else
    {
      auto check_one = [&]<typename T>()
        -> std::optional<std::vector<std::tuple<std::string, std::string, std::string>>>
      {
        auto old_query = old_conn->get_all<T>(), new_query = new_conn->get_all<T>();
        auto old_data_it = old_query.begin(), new_data_it = new_query.begin();
        for (; old_data_it != old_query.end() && new_data_it != new_query.end(); ++old_data_it, ++new_data_it)
          if (*old_data_it != *new_data_it)
          {
            std::cerr << "Data mismatch: {} {} != {}.\n"_f(nameof::nameof_type<T>(), old_data_it->Id, new_data_it->Id);
            return {};
          }
        if (old_data_it != old_query.end() && new_data_it == new_query.end())
          { std::cerr << "Data mismatch in {}.\n"_f(nameof::nameof_type<T>()); return {}; }
        else if constexpr (requires(T data) { data.Signature; })
        {
          std::vector<std::tuple<std::string, std::string, std::string>> diff;
          for (; old_data_it != old_query.end(); ++old_data_it)
          {
            auto data = *old_data_it;
            data.Signature = "";
            data.Id = 0;
            diff.push_back({ serialize(data), old_data_it->Signature, old_data_it->Key });
          }
          return diff;
        }
        else return std::vector<std::tuple<std::string, std::string, std::string>>{};
      };
      auto check_many = [&]<typename T, typename... Ts>(auto&& self)
        -> std::optional<std::vector<std::tuple<std::string, std::string, std::string>>>
      {
        if (auto diff = check_one.operator()<T>(); !diff) return std::nullopt;
        else if constexpr (sizeof...(Ts) == 0) return diff;
        else if (auto diff2 = self.template operator()<Ts...>(self); !diff2) return std::nullopt;
        else { diff->insert(diff->end(), diff2->begin(), diff2->end()); return diff; }
      };
      return check_many.operator()<LoginData, LogoutData, SubmitJobData, FinishJobData>(check_many);
    }
  }
  // search corresponding job in submit table
  std::optional<SubmitJobData> search_job_in_submit(auto connection, unsigned job_id, std::string submit_time)
  {
    std::optional<SubmitJobData> result;
    long submit_date = [&]
    {
      std::chrono::system_clock::time_point submit_date_with_local;
      std::stringstream(submit_time) >> date::parse("%b %d %H:%M:%S %Y", submit_date_with_local);
      date::zoned_time submit_date_with_zone
      (
        date::current_zone(),
        date::local_seconds
        {
          std::chrono::seconds(std::chrono::duration_cast<std::chrono::seconds>
            (submit_date_with_local.time_since_epoch()).count())
        }
      );
      auto submit_date = submit_date_with_zone.get_sys_time();
      return std::chrono::duration_cast<std::chrono::seconds>(submit_date.time_since_epoch()).count();
    }();
    auto submit_jobs = connection->template get_all<SubmitJobData>
      (sqlite_orm::where(sqlite_orm::is_equal(&SubmitJobData::JobId, job_id)));
    for (auto& job_submit : submit_jobs)
      if (auto diff = job_submit.Time - submit_date; std::abs(diff) < 3600)
      {
        result = job_submit;
        if (std::abs(diff) > 60) std::cerr << "large difference found: {} {}\n"_f(job_id, diff);
        break;
      }
    return result;
  }
  bool export_data(long start_time, long end_time, std::string filename)
  {
    if (auto conn = connect(); !conn) return false;
    else
    {
      struct StatResult
      {
        double CpuTime = 0;
        unsigned LoginInteractive = 0, LoginNonInteractive = 0, SubmitJob = 0, FinishJobSuccess = 0,
          FinishJobFailed = 0;
        StatResult& operator+=(const StatResult& rhs)
        {
          CpuTime += rhs.CpuTime;
          LoginInteractive += rhs.LoginInteractive;
          LoginNonInteractive += rhs.LoginNonInteractive;
          SubmitJob += rhs.SubmitJob;
          FinishJobSuccess += rhs.FinishJobSuccess;
          FinishJobFailed += rhs.FinishJobFailed;
          return *this;
        }
      };
      // Key SubAccount -> StatResult
      std::map<std::pair<std::string, std::optional<std::string>>, StatResult> stat;
      // CpuTime & FinishJobSuccess & FinishJobFailed
      for
      (
        auto& it : conn->get_all<FinishJobData>(sqlite_orm::where
          (sqlite_orm::between(&FinishJobData::Time, start_time, end_time)))
      )
      {
        auto job_in_submit = search_job_in_submit
          (conn, it.JobId, it.SubmitTime);
        std::pair<std::string, std::optional<std::string>> key;
        if (!job_in_submit) key = { "", {} };
        else key = std::make_pair(job_in_submit->Key, job_in_submit->Subaccount);
        stat[key].CpuTime += it.CpuTime / 3600;
        if (it.JobResult == "DONE") stat[key].FinishJobSuccess++;
        else stat[key].FinishJobFailed++;
      }
      // LoginInteractive & LoginNonInteractive
      for
      (
        auto& it : conn->get_all<LoginData>(sqlite_orm::where
          (sqlite_orm::between(&LoginData::Time, start_time, end_time)))
      )
      {
        auto key = std::make_pair(it.Key, it.Subaccount);
        if (it.Interactive) stat[key].LoginInteractive++; else stat[key].LoginNonInteractive++;
      }
      // SubmitJob
      for
      (
        auto& it : conn->get_all<SubmitJobData>(sqlite_orm::where
          (sqlite_orm::between(&SubmitJobData::Time, start_time, end_time)))
      )
        stat[{it.Key,it.Subaccount }].SubmitJob++;
      // add all result with subaccount into result without subaccount
      std::map<std::string, StatResult> stat_without_subaccount;
      for (auto& [key, value] : stat) stat_without_subaccount[key.first] += value;
      // remove all result without subaccount
      std::erase_if(stat, [](auto& it) { return !it.first.second; });
      // write to excel
      OpenXLSX::XLDocument doc;
      doc.create(filename);
      doc.workbook().addWorksheet("Statistics");
      auto wks1 = doc.workbook().worksheet("Statistics");
      wks1.row(1).values() = std::vector<std::string>
      {
        "Username", "FingerPrint", "CpuTime", "LoginInteractive", "LoginNonInteractive",
        "SubmitJob", "FinishJobSuccess", "FinishJobFailed"
      };
      for
      (
        auto [row, it] = std::tuple(2, stat_without_subaccount.begin());
        it != stat_without_subaccount.end();
        it++, row++
      )
        wks1.row(row).values() = std::vector<std::string>
        {
          Keys.contains(it->first) ? Keys[it->first].Username : "(unknown)", it->first,
          "{:.2f}"_f(it->second.CpuTime), "{}"_f(it->second.LoginInteractive),
          "{}"_f(it->second.LoginNonInteractive), "{}"_f(it->second.SubmitJob),
          "{}"_f(it->second.FinishJobSuccess), "{}"_f(it->second.FinishJobFailed)
        };
      doc.workbook().addWorksheet("StatisticsWithSubAccount");
      auto wks2 = doc.workbook().worksheet("StatisticsWithSubAccount");
      wks2.row(1).values() = std::vector<std::string>
      {
        "Username::SubAccount", "CpuTime", "LoginInteractive", "LoginNonInteractive",
        "SubmitJob", "FinishJobSuccess", "FinishJobFailed"
      };
      for (auto [row, it] = std::tuple(2, stat.begin()); it != stat.end(); it++, row++)
        wks2.row(row).values() = std::vector<std::string>
        {
          (Keys.contains(it->first.first) ? Keys[it->first.first].Username : "(unknown)")
            + "::" + *it->first.second,
          "{:.2f}"_f(it->second.CpuTime), "{}"_f(it->second.LoginInteractive),
          "{}"_f(it->second.LoginNonInteractive), "{}"_f(it->second.SubmitJob),
          "{}"_f(it->second.FinishJobSuccess), "{}"_f(it->second.FinishJobFailed)
        };
      doc.workbook().deleteSheet("Sheet1");
      doc.save();
      return true;
    }
  }
  std::optional<std::map<unsigned, std::tuple<std::string, std::string, std::string, std::optional<std::string>>>>
    check_job_status()
  {
    if (auto conn = connect(); !conn) return std::nullopt;
    else if (auto jobs_current = lfs::bjobs_list(); !jobs_current) return std::nullopt;
    else
    {
      auto jobs_previous_query_result = conn->get_all<CheckJobData>();
      auto jobs_previous = jobs_previous_query_result
        | ranges::views::transform([](auto& it) { return std::pair{it.JobId, it.Status}; })
        | ranges::to<std::map<unsigned, std::string>>;
      std::map<unsigned,  std::tuple<std::string, std::string, std::string, std::optional<std::string>>> result;
      for (auto& [job_id, status] : *jobs_current)
        if (!jobs_previous.contains(job_id) || jobs_previous[job_id] != std::get<1>(status))
          if
          (
            auto job_in_submit =
              search_job_in_submit(conn, job_id, std::get<0>(status));
            job_in_submit
          )
            result[job_id] =
              { std::get<3>(status), std::get<1>(status), job_in_submit->Key, job_in_submit->Subaccount };
      conn->remove_all<CheckJobData>();
      auto new_data = *jobs_current
        | ranges::views::transform
          ([](auto& it) { return CheckJobData{ .JobId = it.first, .Status = std::get<1>(it.second) }; })
        | ranges::to<std::vector<CheckJobData>>;
      conn->insert_range(new_data.begin(), new_data.end());
      return result;
    }
  }
}
