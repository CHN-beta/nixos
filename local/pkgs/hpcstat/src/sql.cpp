# include <filesystem>
# include <set>
# include <hpcstat/sql.hpp>
# include <hpcstat/env.hpp>
# include <range/v3/range.hpp>
# include <range/v3/view.hpp>
# include <nameof.hpp>
# include <fmt/format.h>

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
  std::optional<zxorm::Connection<LoginTable, LogoutTable, SubmitJobTable, FinishJobTable>> connect
    (std::optional<std::string> dbfile = std::nullopt)
  {
    if (dbfile) return std::make_optional<zxorm::Connection<LoginTable, LogoutTable, SubmitJobTable, FinishJobTable>>
      (dbfile->c_str(), SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX);
    else if (auto datadir = env::env("HPCSTAT_DATADIR", true); !datadir)
      return std::nullopt;
    else
    {
      auto dbfile = std::filesystem::path(*datadir) / "hpcstat.db";
      return std::make_optional<zxorm::Connection<LoginTable, LogoutTable, SubmitJobTable, FinishJobTable>>
        (dbfile.c_str(), SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX);
    }
  }
  bool initdb()
    { if (auto conn = connect(); !conn) return false; else { conn->create_tables(); return true; } }
  bool writedb(auto value)
    { if (auto conn = connect(); !conn) return false; else { conn->insert_record(value); return true; } }
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
      auto not_logged_job = all_job | ranges::to<std::set<unsigned>>;
      for (auto it : conn->select_query<FinishJobData>()
        .order_by<FinishJobTable::field_t<"id">>(zxorm::order_t::DESC)
        .where_many(FinishJobTable::field_t<"job_id">().in(all_job))
        .exec())
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
        auto old_query = old_conn->select_query<T>().many().exec(),
          new_query = new_conn->select_query<T>().many().exec();
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
