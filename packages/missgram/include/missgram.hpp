# include <biu.hpp>

namespace missgram
{
  struct Config
  {
    std::string Secret;
    std::string TelegramBotToken;
    std::int64_t TelegramChatId;
    std::int16_t ServerPort;
    std::string dbPassword;
  } inline config;
  struct File { std::string url; bool is_photo; bool should_hidden; };

  void db_write(std::string misskey_note, std::int32_t telegram_message_id);
  std::optional<std::int32_t> db_read(std::string misskey_note);

  std::optional<std::int32_t> tg_send(std::string text, std::optional<std::int32_t> replyId, std::vector<File> files);
}
