# include <biu.hpp>

namespace missgram
{
  void db_write(std::string misskey_note, int telegram_message_id);
  std::optional<int> db_read(std::string misskey_note);

  std::optional<int> tg_send(std::string text, std::optional<int> replyId = {});

  struct Config
  {
    std::string Secret;
    std::string TelegramBotToken;
    int TelegramChatId;
    int ServerPort;
    std::string dbPassword;
  } inline config;
}
