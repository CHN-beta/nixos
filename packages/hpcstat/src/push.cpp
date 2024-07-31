# include <hpcstat/push.hpp>
# include <hpcstat/env.hpp>
# include <nlohmann/json.hpp>
# include <httplib.h>
# include <boost/url.hpp>
# include <nameof.hpp>
# include <range/v3/view.hpp>

namespace hpcstat::push
{
  // 任务 id，名称、现在的状态、提交时的 key、subaccount
  bool push(std::map<unsigned, std::tuple<std::string, std::string, std::string, std::optional<std::string>>> data)
  {
    // 读取配置
    if (auto datadir = env::env("HPCSTAT_DATADIR"); !datadir) return false;
    else if (std::ifstream config_file(std::filesystem::path(*datadir) / "push.json"); !config_file)
      { std::cout << "Push failed: failed to open push.json\n"; return false; }
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
          auto path = "/api/send/message/?appToken={}&content={}&uid={}"_f
          (
            token,
            boost::urls::encode
            (
              "{} {} {}"_f(std::get<1>(info), std::get<0>(info), id),
              boost::urls::unreserved_chars
            ),
            users[user_string]
          );
          auto res = cli.Get(path.c_str());
          if (res.error() != httplib::Error::Success) { std::cout << "Push failed: {}\n"_f(res.error()); return false; }
        }
      }
    }
    // push to telegram for chn
    {
      auto messages = data
        | ranges::views::filter([](const auto& pair)
          { return std::get<2>(pair.second) == "LNoYfq/SM7l8sFAy325WpC+li+kZl3jwST7TmP72Tz8"; })
        | ranges::views::transform([](const auto& pair)
          { return "{} {} {}"_f(std::get<1>(pair.second), std::get<0>(pair.second), pair.first); })
        | ranges::views::chunk(20)
        | ranges::views::transform([](auto chunk) { return chunk | ranges::views::join('\n'); })
        | ranges::to<std::vector<std::string>>;
      if (!messages.empty())
      {
        httplib::Client cli("https://api.chn.moe");
        cli.enable_server_certificate_verification(false);
        for (auto& message : messages)
        {
          auto path = "/notify.php?message={}"_f
            (boost::urls::encode(message, boost::urls::unreserved_chars));
          auto res = cli.Get(path.c_str());
          if (res.error() != httplib::Error::Success)
            { std::cout << "Push failed: {}\n"_f(res.error()); return false; }
          else if (res->status != 200)
            { std::cout << "Push failed: status code {}\n"_f(res->status); return false; }
        }
      }
    }
    return true;
  }
}
