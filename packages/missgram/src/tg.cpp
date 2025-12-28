# include <missgram.hpp>
# include <tgbot/tgbot.h>

std::optional<std::int32_t> missgram::tg_send(std::string text, std::optional<std::int32_t> replyId)
{
  using namespace biu::literals;

  // 准备信息
  TgBot::Bot bot(config.TelegramBotToken);
  std::shared_ptr<TgBot::ReplyParameters> reply;
  if (replyId) reply = std::make_shared<TgBot::ReplyParameters>(*replyId);

  // 发送信息，带重试机制
  TgBot::Message::Ptr message;
  auto retry_delay = 1s;
  int attempts = 0;
  while (attempts < 5 && !message)
  {
    biu::Logger::try_exec([&]
    {
      message = bot.getApi().sendMessage
        (config.TelegramChatId, text, nullptr, reply);
    });
    if (!message) { std::this_thread::sleep_for(retry_delay); retry_delay *= 2; attempts++; }
  }

  // 返回消息 ID
  if (message) return message->messageId; else return {};
}
