# include <missgram.hpp>
# include <httplib.h>

# ifndef MISSGRAM_CONFIG_FILE
#   define MISSGRAM_CONFIG_FILE "./config.yaml"
# endif

int main()
{
  using namespace biu::literals;
  using namespace missgram;
  biu::Logger::Guard log;

  config = YAML::LoadFile(MISSGRAM_CONFIG_FILE).as<Config>();

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
          struct
          {
            struct Note
            {
              std::string id, text, visibility;
              std::optional<std::string> replyId;
              struct Renote { std::string id; };
              std::optional<Renote> renote;
            };
            std::optional<Note> note;
          } body;
        };
        auto content = YAML::Load(req.body).as<Content>();

        if
        (
          content.type != "note"    // 只转发 note 的情况
            || !content.body.note   // 大概不会发生，但还是判断一下
            || content.body.note->visibility != "public"  // 只转发公开的 note
            || content.body.note->replyId // 不转发回复
        ) return;
        std::string text = content.body.note->text;
        if (content.body.note->renote)
          text += "\n🔁 Renote: {}/notes/{}"_f(content.server, content.body.note->renote->id);

        std::thread([text, note_id = content.body.note->id]
        {
          auto message_id = tg_send(text);
          if (message_id) db_write(note_id, *message_id);
        }).detach();

        res.status = 200;
        res.body = "OK";

        log.debug(req.body);
      });
    });
    svr.listen("0.0.0.0", config.ServerPort);
    return 0;
  });
}
