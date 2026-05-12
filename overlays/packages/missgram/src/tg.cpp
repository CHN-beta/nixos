# include <missgram.hpp>
# include <httplib.h>
# include <nlohmann/json.hpp>

std::optional<std::int32_t> missgram::tg_send
(
  std::string text, std::optional<std::int32_t> replyId, std::vector<File> files,
  std::optional<std::string> preview_url
)
{
  using namespace biu::literals;
  biu::Logger::Guard log(text, replyId, files, preview_url);

  // 多次尝试运行函数，直到成功或达到最大尝试次数（5次）
  auto try_run = [&](auto&& func) -> std::optional<decltype(func())>
  {
    auto retry_delay = 1s;
    int attempts = 0;
    while (attempts < 5)
    {
      std::optional<decltype(func())> result;
      biu::Logger::try_exec([&] { result = func(); });
      if (result) return result;
      std::this_thread::sleep_for(retry_delay);
      retry_delay *= 2;
      attempts++;
    }
    return {};
  };

  // 下载一个 https 资源到内存
  auto download = [&](const std::string& url) -> std::string
  {
    std::regex https_regex(R"(https://([^/]+)(/.+))");
    std::smatch match;
    if (!std::regex_match(url, match, https_regex))
      throw std::runtime_error("Only https URLs are supported");
    httplib::SSLClient cli(match[1].str());
    auto res = cli.Get(match[2].str());
    if (res && res->status == 200) return res->body;
    else throw std::runtime_error("Failed to download file from " + url);
  };

  // 下载要发送的文件
  std::vector<std::string> file_contents;
  for (const auto& file : files)
  {
    auto content = try_run([&] { return download(file.url); });
    if (!content) throw std::runtime_error("Failed to download file from " + file.url);
    file_contents.push_back(std::move(*content));
  }

  // 准备要发送的请求
  httplib::UploadFormDataItems items;
  std::string method;
  if (files.empty())
  {
    method = "sendMessage";
    items.push_back({"text", text});
    items.push_back({"parse_mode", "HTML"});
    items.push_back({"link_preview_options", [&]
    {
      nlohmann::json j;
      if (preview_url) j["url"] = *preview_url; else j["is_disabled"] = true;
      return j.dump();
    }()});
  }
  else if (files.size() == 1)
  {
    auto is_photo = files[0].type.starts_with("image/");
    method = is_photo ? "sendPhoto" : "sendDocument";
    items.push_back
    ({
      is_photo ? "photo" : "document",
      file_contents[0], files[0].name, files[0].type
    });
    items.push_back({"caption", text});
    items.push_back({"parse_mode", "HTML"});
    if (is_photo && files[0].isSensitive) items.push_back({"has_spoiler", "True"});
  }
  else
  {
    method = "sendMediaGroup";
    auto all_photo = ranges::all_of(files,
      [](auto&& file) { return file.type.starts_with("image/"); });
    nlohmann::json media_group = files | ranges::views::enumerate | ranges::views::transform([&](auto&& file)
    {
      nlohmann::json params;
      if (all_photo)
      {
        params["type"] = "photo";
        if (file.second.isSensitive) params["has_spoiler"] = true;
      }
      else params["type"] = "document";
      params["media"] = "attach://media-{}"_f(file.first);
      log.debug("Prepared media {}: {}"_f(file.first, params.dump()));
      if (file.first == 0) { params["caption"] = text; params["parse_mode"] = "HTML"; }
      return params;
    }) | ranges::to_vector;
    items.push_back({"media", media_group.dump()});
    for (int i = 0; i < files.size(); i++) items.push_back
      ({"media-{}"_f(i), file_contents[i], files[i].name, files[i].type});
  }
  items.push_back({"chat_id", std::to_string(config.TelegramChatId)});
  if (replyId) items.push_back({"reply_parameters", [&]
    { nlohmann::json j; j["message_id"] = *replyId; return j.dump(); }()});

  httplib::Client cli("https://api.telegram.org");
  auto result = cli.Post("/bot{}/{}"_f(config.TelegramBotToken, method), items);
  log.debug("{} {} {}"_f(result->status, result->body, result->headers));
  if (result && result->status == 200)
  {
    auto json = nlohmann::json::parse(result->body);
    // 测试 js["result"]["message_id"] 是否存在且为整数
    if (json.contains("result") && json["result"].contains("message_id")
      && json["result"]["message_id"].is_number_integer())
      return json["result"]["message_id"].get<std::int32_t>();
    else
    {
      log.error("Telegram API error: {}"_f(json.dump()));
      return {};
    }
  }
  else
  {
    log.error("HTTP error: {}"_f(result ? std::to_string(result->status) : "No response"));
    return {};
  }
}
