# include <missgram.hpp>
# define CPPHTTPLIB_THREAD_POOL_COUNT 1
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
              std::optional<std::string> text, replyId, cw;
              struct Renote { std::string id; };
              std::optional<Renote> renote;
              bool localOnly;
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

        // 如果是转发/回复/引用，需要检查被回复或者被引用的帖子是否已经被转发过
        bool is_forward = !content.body.note->text && content.body.note->renote;
        bool is_renote = content.body.note->text && content.body.note->renote;
        bool is_reply = content.body.note->replyId.has_value();
        std::optional<std::uint32_t> tg_reply_id;
        bool fond_renote = false, found_reply = false;
        if (is_reply)
          { tg_reply_id = db_read(*content.body.note->replyId); found_reply = tg_reply_id.has_value(); }
        else if (is_forward || is_renote)
          { tg_reply_id = db_read(content.body.note->renote->id); fond_renote = tg_reply_id.has_value(); }

        // 一些情况下，需要生成预览链接
        // 优先回复的帖子，然后是引用的帖子，最后是正文中的第一个链接
        std::optional<std::string> preview_url;
        if (is_reply && !found_reply) preview_url = "{}/notes/{}"_f(content.server, *content.body.note->replyId);
        else if ((is_forward || is_renote) && !fond_renote)
          preview_url = "{}/notes/{}"_f(content.server, content.body.note->renote->id);
        else if (content.body.note->text)
        {
          // 检查文本中是否有url，有的话就用第一个url作为预览链接
          std::regex url_regex(R"((https?://[^\s\(\)\[\]\{\}]+))");
          std::smatch match;
          if (std::regex_search(*content.body.note->text, match, url_regex))
            preview_url = match.str(1);
        }

        // 接下来准备要回复的文本内容
        std::string text_html;
        if (is_forward)  // 如果是转发帖子
          if (fond_renote) text_html = "转发了自己的帖子。";
          else text_html = parse("转发了[帖子]({}/notes/{})"_f(content.server, content.body.note->id));
        // 否则（引用或普通帖子）
        else
        {
          std::string text = content.body.note->text.value_or("");
          if (is_reply)
          {
            // 移除开头的 @user 或者 @user@server
            std::regex reply_regex(R"(^@\S+(@\S+)?\s*)");
            std::string new_text;
            while (new_text = std::regex_replace(text, reply_regex, ""), new_text != text) text = new_text;
          }
          if (is_renote && !fond_renote)
            text = "引用了[帖子]({}/notes/{})\n"_f(content.server, content.body.note->renote->id) + text;
          if (is_reply && !found_reply)
            text = "回复了[帖子]({}/notes/{})\n"_f(content.server, *content.body.note->replyId) + text;
          text_html = parse(text);
          // 可能还有content warning，如果有的话需要处理
          if (content.body.note->cw && !content.body.note->cw->empty())
          {
            std::string cw_html = parse(*content.body.note->cw);
            text_html = R"({}<span class="tg-spoiler">{}</span>)"_f(cw_html, text_html);
          }
          text_html += parse("\n[在联邦宇宙查看]({}/notes/{})"_f(content.server, content.body.note->id));
        }

        // 异步发送消息
        std::thread([text_html, note_id = content.body.note->id, tg_reply_id,
          files = content.body.note->files, preview_url]
        {
          auto message_id =
            tg_send(text_html, tg_reply_id, files, preview_url);
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
