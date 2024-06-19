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
            diff.push_back({ biu::serialize<char>(data), old_data_it->Signature, old_data_it->Key });
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
      // 对于一个账户的总计
      struct StatAccount
      {
        double CpuTime = 0;
        unsigned LoginInteractive = 0, LoginNonInteractive = 0, FinishJobSuccess = 0, FinishJobFailed = 0;
      };
      // Key SubAccount -> StatAccount
      std::map<std::pair<std::string, std::string>, StatAccount> stat_subaccount;
      // Key -> StatAccount
      std::map<std::optional<std::string>, StatAccount> stat_account;
      // 每一个任务
      struct StatJob
      {
        unsigned JobId;
        std::optional<std::string> Key, SubmitDir, JobCommand;
        std::string JobResult, SubmitTime, JobDetail;
        double CpuTime;
      };
      std::vector<StatJob> stat_job;
      // CpuTime & FinishJobSuccess & FinishJobFailed
      for
      (
        auto& it : conn->get_all<FinishJobData>(sqlite_orm::where
          (sqlite_orm::between(&FinishJobData::Time, start_time, end_time)))
      )
      {
        stat_job.push_back
        ({
          .JobId = it.JobId, .JobResult = it.JobResult, .SubmitTime = it.SubmitTime, .JobDetail = it.JobDetail,
          .CpuTime = it.CpuTime / 3600
        });
        if (auto job_in_submit = search_job_in_submit
          (conn, it.JobId, it.SubmitTime))
        {
          {
            auto& _ = stat_job.back();
            _.Key = job_in_submit->Key;
            _.SubmitDir = job_in_submit->SubmitDir;
            _.JobCommand = job_in_submit->JobCommand;
          }
          stat_account[job_in_submit->Key].CpuTime += it.CpuTime / 3600;
          if (it.JobResult == "DONE") stat_account[job_in_submit->Key].FinishJobSuccess++;
          else stat_account[job_in_submit->Key].FinishJobFailed++;
          if (job_in_submit->Subaccount)
          {
            stat_subaccount[{job_in_submit->Key, *job_in_submit->Subaccount}].CpuTime += it.CpuTime / 3600;
            if (it.JobResult == "DONE")
              stat_subaccount[{job_in_submit->Key, *job_in_submit->Subaccount}].FinishJobSuccess++;
            else stat_subaccount[{job_in_submit->Key, *job_in_submit->Subaccount}].FinishJobFailed++;
          }
        }
        else
        {
          stat_account[std::nullopt].CpuTime += it.CpuTime / 3600;
          if (it.JobResult == "DONE") stat_account[std::nullopt].FinishJobSuccess++;
          else stat_account[std::nullopt].FinishJobFailed++;
        }
      }
      // LoginInteractive & LoginNonInteractive
      for
      (
        auto& it : conn->get_all<LoginData>(sqlite_orm::where
          (sqlite_orm::between(&LoginData::Time, start_time, end_time)))
      )
      {
        if (Keys[it.Key].Username == "hpcstat") continue;
        if (it.Interactive) stat_account[it.Key].LoginInteractive++; else stat_account[it.Key].LoginNonInteractive++;
        if (it.Subaccount)
        {
          if (it.Interactive) stat_subaccount[{it.Key, *it.Subaccount}].LoginInteractive++;
          else stat_subaccount[{it.Key, *it.Subaccount}].LoginNonInteractive++;
        }
      }
      // export to markdown
      std::cout << "| 账号 | 使用核时 | 登陆次数(总计/交互式/非交互式) | 完成任务(总计/成功/失败) | SSH密钥编号::指纹 |\n";
      std::cout << "| :--: | :--: | :--: | :--: | :--: |\n";
      std::vector<std::pair<std::optional<std::string>, StatAccount>> stat_account_vector
        (stat_account.begin(), stat_account.end());
      auto compare = [](auto& a, auto& b)
      {
        if (a.first)
          { if (b.first) return Keys[*a.first].PubkeyFilename < Keys[*b.first].PubkeyFilename; else return true; }
        else return false;
      };
      std::sort(stat_account_vector.begin(), stat_account_vector.end(), compare);
      for (auto& [key, stat] : stat_account_vector)
        std::cout << "| {} | {:.2f} | {}/{}/{} | {}/{}/{} | `{}` |\n"_f
        (
          key ? Keys[*key].Username : "(unknown)", stat.CpuTime,
          stat.LoginInteractive + stat.LoginNonInteractive, stat.LoginInteractive, stat.LoginNonInteractive,
          stat.FinishJobSuccess + stat.FinishJobFailed, stat.FinishJobSuccess, stat.FinishJobFailed,
          key ? "{}::SHA256:{}"_f(Keys[*key].PubkeyFilename, *key) : "(unknown)"
        );
      for (auto& [key_subaccount, stat] : stat_subaccount)
        std::cout << "| {}::{} | {:.2f} | {} | {} | {} | {} | `{}::{}` |\n"_f
        (
          Keys[key_subaccount.first].Username, key_subaccount.second, stat.CpuTime,
          stat.LoginInteractive, stat.LoginNonInteractive, stat.FinishJobSuccess, stat.FinishJobFailed,
          Keys[key_subaccount.first].PubkeyFilename, key_subaccount.first
        );
      // export to excel
      OpenXLSX::XLDocument doc;
      doc.create(filename);
      auto wks1 = doc.workbook().worksheet("Sheet1");
      wks1.row(1).values() = std::vector<std::string>
      {
        "用户", "任务ID", "结果", "核时", "提交时间", "提交时当前目录", "提交命令",
        "详情"
      };
      for (auto [row, it] = std::tuple(2, stat_job.begin()); it != stat_job.end(); it++, row++)
        wks1.row(row).values() = std::vector<std::string>
        {
          Keys.contains(*it->Key) ? Keys[*it->Key].Username : "(unknown)",
          "{}"_f(it->JobId), it->JobResult, "{:.2f}"_f(it->CpuTime), it->SubmitTime,
          it->SubmitDir.value_or("(unknown)"), it->JobCommand.value_or("(unknown)"),
          it->JobDetail
        };
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
