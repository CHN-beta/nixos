# include <biu.hpp>
# include <httplib.h>
# include <tgbot/tgbot.h>
# ifndef FORWARDER_CONFIG_FILE
#   define FORWARDER_CONFIG_FILE "./config.yml"
# endif

int main()
{
  using namespace biu::literals;
  biu::Logger::Guard log;

  struct Config
  {
    std::string Secret;
    std::string TelegramBotToken;
    std::string TelegramChatId;
    int ServerPort;
  };
  auto config = YAML::LoadFile(FORWARDER_CONFIG_FILE).as<Config>();

  biu::Logger::try_exec([&]
  {
    httplib::Server svr;

    svr.Post("/", [&](const httplib::Request& req, httplib::Response& res)
    {
      biu::Logger::try_exec([&]
      {
        if (req.get_header_value("x-misskey-hook-secret") != config.Secret)
          throw std::runtime_error("Invalid secret key.");

        struct Content
        {
          std::string type, server;
          struct { struct
          {
            std::string text, visibility;
            struct Renote { std::string id; };
            std::optional<Renote> renote;
          } note; } body;
        };
        auto content = YAML::Load(req.body).as<Content>();

        if (content.type != "note" || content.body.note.visibility != "public") return;
        std::string text = content.body.note.text;
        if (content.body.note.renote)
          text += "\n🔁 Renote: https://{}/notes/{}"_f(content.server, content.body.note.renote->id);

        TgBot::Bot bot(config.TelegramBotToken);
        bot.getApi().sendMessage(config.TelegramChatId, text);

        res.status = 200;
        res.body = "OK";
      });
    });
    svr.listen("0.0.0.0", config.ServerPort);
    return 0;
  });
}
