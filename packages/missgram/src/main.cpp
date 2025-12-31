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
        log.debug(req.body);
        log.debug("{}"_f(req.headers));

        if (req.get_header_value("x-misskey-hook-secret") != config.Secret)
          throw std::runtime_error("Invalid secret key.");

        struct Content
        {
          std::string type, server;
          struct Body
          {
            struct Note
            {
              std::string id, visibility;
              std::optional<std::string> text, replyId;
              struct Renote { std::string id; };
              std::optional<Renote> renote;
              bool localOnly;
              struct File { bool isSensitive; std::string url; std::string type; };
              std::vector<File> files;
            };
            std::optional<Note> note;
          } body;
        };
        auto content = YAML::Load(req.body).as<Content>();

        log();

        // 只考虑公开且允许联合的帖子。
        if
        (
          content.type != "note"    // 只考虑 note 的情况，这里note包括了回复、转发、引用
            || !content.body.note   // 大概不会发生，但还是判断一下
            || content.body.note->visibility != "public" || content.body.note->localOnly // 只转发公开的、允许联合的帖子
        ) return;

        // 接下来准备要转发的文字内容
        std::string text;
        std::optional<std::uint32_t> reply_id;
        // 如果是转发，则直接写链接
        if (!content.body.note->text && content.body.note->renote)
          text = "转发了[帖子]({}/notes/{})"_f(content.server, content.body.note->id);
        // 否则（引用或普通帖子）
        else
        {
          text = *content.body.note->text;
          // 如果有引用，则需要查找被引用的帖子是否已经被转发过，若是则直接回复被转发的消息。
          // 如果没有被转发过，则在开头附上链接
          if (content.body.note->renote)
          {
            reply_id = db_read(content.body.note->renote->id);
            if (!reply_id)
              text = "引用了[帖子]({}/notes/{})\n"_f(content.server, content.body.note->renote->id) + text;
          }
          // 检查是否是回复帖子，若是则在开头附上链接原帖链接。我一般不直接回复自己的帖子，所以这里不检查
          if (content.body.note->replyId)
            text = "回复了[帖子]({}/notes/{})\n"_f(content.server, *content.body.note->replyId) + text;
          // 最后附上原贴地址
          text += "\n[在联邦宇宙查看]({}/notes/{})"_f(content.server, content.body.note->id);
        }

        // 接下来整理要转发的文件
        auto files = content.body.note->files | ranges::views::transform([](auto&& file) -> File
        {
          return File
          {
            .url = file.url,
            .is_photo = file.type.starts_with("image/"),
            .should_hidden = file.isSensitive
          };
        }) | ranges::to_vector;

        log();

        // 异步发送消息
        std::thread([text, note_id = content.body.note->id, reply_id, files]
        {
          auto message_id = tg_send(text, reply_id, files);
          if (message_id) db_write(note_id, *message_id);
        }).detach();

        // 完成 http 响应
        res.status = 200;
        res.body = "OK";
      });
    });
    svr.listen("0.0.0.0", config.ServerPort);
    return 0;
  });
}
