# include <missgram.hpp>
# include <sqlgen/postgres.hpp>

struct Record { std::string misskey_note; std::int32_t telegram_message_id; };

namespace missgram { std::mutex db_mutex; }

void missgram::db_write(std::string misskey_note, std::int32_t telegram_message_id)
{
  std::lock_guard lock(db_mutex);
  biu::Logger::Guard log(misskey_note, telegram_message_id);
  auto&& conn = sqlgen::postgres::connect
    ({.user = "missgram", .password = config.dbPassword, .host = "127.0.0.1", .dbname = "missgram"});
  sqlgen::write(conn, Record{misskey_note, telegram_message_id});
}

std::optional<std::int32_t> missgram::db_read(std::string misskey_note)
{
  std::lock_guard lock(db_mutex);
  biu::Logger::Guard log(misskey_note);
  using namespace sqlgen::literals;
  auto&& conn = sqlgen::postgres::connect
    ({.user = "missgram", .password = config.dbPassword, .host = "127.0.0.1", .dbname = "missgram"});
  auto query = sqlgen::read<std::vector<Record>> |
    sqlgen::where("misskey_note"_c == misskey_note) |
    sqlgen::limit(1);
  auto result = query(conn);
  if (!result || result->empty()) return {}; else return result->front().telegram_message_id;
}
