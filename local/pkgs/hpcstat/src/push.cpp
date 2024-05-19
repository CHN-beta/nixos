# include <hpcstat/push.hpp>
# include <hpcstat/env.hpp>
# include <nlohmann/json.hpp>
# include <httplib.h>
# include <boost/url.hpp>
# include <nameof.hpp>

namespace hpcstat::push
{
  // 任务 id，名称、现在的状态、提交时的 key、subaccount
  bool push(std::map<unsigned, std::tuple<std::string, std::string, std::string, std::optional<std::string>>> data)
  {
    // 读取配置
    if (auto datadir = env::env("HPCSTAT_DATADIR"); !datadir) return false;
    else if (std::ifstream config_file(std::filesystem::path(*datadir) / "push.json"); !config_file)
      { fmt::print("Push failed: failed to open push.json\n"); return false; }
    else
    {
      auto config_string = std::string(std::istreambuf_iterator<char>(config_file), {});
      auto config = nlohmann::json::parse(config_string);
      auto token = config["token"].get<std::string>();
      auto users = config["users"].get<std::map<std::string, std::string>>();
      httplib::Client cli("http://wxpusher.zjiecode.com");
      for (const auto& [id, info] : data)
      {
        auto user_string = std::get<2>(info);
        if (std::get<3>(info))
          user_string += "::" + *std::get<3>(info);
        if (users.contains(user_string))
        {
          auto path = fmt::format
          (
            "/api/send/message/?appToken={}&content={}&uid={}",
            token,
            boost::urls::encode
            (
              fmt::format("{} {} {}", std::get<1>(info), std::get<0>(info), id),
              boost::urls::unreserved_chars
            ),
            users[user_string]
          );
          auto res = cli.Get(path.c_str());
          if (res.error() != httplib::Error::Success)
            { fmt::print("Push failed: {}\n", nameof::nameof_enum(res.error())); return false; }
        }
      }
    }
    // push to telegram for chn
    for (const auto& [id, info] : data)
      if (std::get<2>(info) == "LNoYfq/SM7l8sFAy325WpC+li+kZl3jwST7TmP72Tz8")
      {
        httplib::Client cli("https://api.chn.moe");
        cli.enable_server_certificate_verification(false);
        auto path = fmt::format
        (
          "/notify.php?message={}",
          boost::urls::encode
            (fmt::format("{} {} {}", std::get<1>(info), std::get<0>(info), id), boost::urls::unreserved_chars)
        );
        auto res = cli.Get(path.c_str());
        if (res.error() != httplib::Error::Success)
          { fmt::print("Push failed: {}\n", nameof::nameof_enum(res.error())); return false; }
      }
    return true;
  }
}
