# include <hpcstat/sql.hpp>
# include <hpcstat/env.hpp>
# include <range/v3/range.hpp>
# include <range/v3/view.hpp>
# include <nameof.hpp>
# define SQLITE_ORM_OPTIONAL_SUPPORTED
# include <sqlite_orm/sqlite_orm.h>

namespace hpcstat::sql
{
  std::string serialize(auto data)
  {
    auto [serialized_data_byte, out] = zpp::bits::data_out();
    out(data).or_throw();
    static_assert(sizeof(char) == sizeof(std::byte));
    return { reinterpret_cast<char*>(serialized_data_byte.data()), serialized_data_byte.size() };
  }
  template std::string serialize(LoginData);
  template std::string serialize(SubmitJobData);
  template std::string serialize(FinishJobData);
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
            std::cerr << fmt::format
              ("Data mismatch: {} {} != {}.\n", nameof::nameof_type<T>(), old_data_it->Id, new_data_it->Id);
            return std::nullopt;
          }
        if (old_data_it != old_query.end() && new_data_it == new_query.end())
        {
          std::cerr << fmt::format("Data mismatch in {}.\n", nameof::nameof_type<T>());
          return std::nullopt;
        }
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
}
