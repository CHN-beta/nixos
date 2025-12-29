# include <missgram.hpp>
# include <tgbot/tgbot.h>

std::optional<std::int32_t> missgram::tg_send
  (std::string text, std::optional<std::int32_t> replyId, std::vector<File> files)
{
  using namespace biu::literals;

  // 整理要发送的信息
  TgBot::Bot bot(config.TelegramBotToken);
  std::shared_ptr<TgBot::ReplyParameters> reply;
  if (replyId) reply = std::make_shared<TgBot::ReplyParameters>(*replyId, config.TelegramChatId);
  auto attachs = files
    | ranges::views::transform([&](auto&& file) -> TgBot::InputMedia::Ptr
    {
      if (file.is_photo)
      {
        auto pic = std::make_shared<TgBot::InputMediaPhoto>();
        pic->media = file.url;
        pic->hasSpoiler = file.should_hidden;
        return pic;
      }
      else
      {
        auto doc = std::make_shared<TgBot::InputMediaDocument>();
        doc->media = file.url;
        return doc;
      }
    })
    | ranges::to_vector;

  // 多次尝试运行函数，直到成功或达到最大尝试次数（5次）
  auto try_run = [&](auto&& func) -> std::optional<std::int32_t>
  {
    auto retry_delay = 1s;
    int attempts = 0;
    while (attempts < 5)
    {
      TgBot::Message::Ptr message;
      biu::Logger::try_exec([&] { message = func(); });
      if (message) return message->messageId;
      std::this_thread::sleep_for(retry_delay);
      retry_delay *= 2;
      attempts++;
    }
    return std::nullopt;
  };

  // 如果没有附件，使用 sendMessage 发送文本消息
  if (attachs.empty()) return try_run([&] { return bot.getApi().sendMessage
  (
    config.TelegramChatId, text, nullptr, reply, nullptr,
    "MarkdownV2"
  );});
  // 如果只有一个附件并且是图片，使用 sendPhoto 发送
  else if (attachs.size() == 1 && files[0].is_photo) return try_run([&]
  {
    return bot.getApi().sendPhoto
    (
      config.TelegramChatId, files[0].url, text, reply,
      nullptr, "MarkdownV2", false, {}, 0, false, files[0].should_hidden
    );
  });
  // 如果有多个附件，使用 sendMediaGroup 分两条消息发送，返回第一条的 id
  else
  {
    auto message = try_run([&] { return bot.getApi().sendMessage
    (
      config.TelegramChatId, text, nullptr, reply, nullptr,
      "MarkdownV2"
    );});
    if (message)
    {
      auto message2 = try_run([&] -> TgBot::Message::Ptr
      {
        auto msg = bot.getApi().sendMediaGroup
        (
          config.TelegramChatId, attachs, false,
          std::make_shared<TgBot::ReplyParameters>(*message, config.TelegramChatId)
        );
        if (msg.empty() || !ranges::all_of(msg, [](auto&& m) { return bool(m); }))
          return nullptr;
        else return msg[0];
      });
      if (!message2) return {};
    }
    return message;
  }
}
