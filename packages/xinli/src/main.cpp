# include <biu.hpp>
# include <httplib.h>
# include <nlohmann/json.hpp>

using namespace biu::literals;

int main(int argc, char **argv)
{
  biu::Logger::Guard log;

  struct Job_t { std::string Type; YAML::Node Params; };
  struct { std::string Cookie; std::vector<Job_t> Jobs; } Config;
  Config = YAML::LoadFile(argv[1]).as<decltype(Config)>();
  log.debug("read cookie: {}"_f(Config.Cookie));

  httplib::Client cli("https://xmuxg.xmu.edu.cn");
  auto get = [&](const std::string &url, httplib::Params params = {}) -> std::optional<std::string>
  {
    biu::Logger::Guard log;
    auto res = cli.Get(url, params, {{"Cookie", Config.Cookie}});
    if (res && res->status == 200) return log.rtn(res->body);
    else { log.error("failed to get {}: {}"_f(url, res ? res->status : 0)); return {}; }
  };
  auto post = [&](const std::string &url, const std::string &body) -> std::optional<std::string>
  {
    biu::Logger::Guard log;
    auto res = cli.Post
      (url, {{"Cookie", Config.Cookie}}, body, "application/json");
    if (res && res->status == 200) return log.rtn(res->body);
    else { log.error("failed to post {}: {}"_f(url, res ? res->status : 0)); return {}; }
  };
  std::map<std::string, std::pair<std::string, std::string>> Campus =
  {
    {"翔安", {"1", "RESERVATION"}},
    {"思明", {"2", "RESERVATION"}},
    {"漳州", {"1588748384174", "RESERVATION"}},
    {"线上", {"1588748384174", "ONLINE"}},
  };

  for (const auto &job : Config.Jobs)
  {
    if (job.Type == "AddSchedule")
    {
      struct { std::string Campus, Name, Date, Time; } params;
      params = job.Params.as<decltype(params)>();
      if (!Campus.contains(params.Campus)) { log.error("unknown campus: {}"_f(params.Campus)); continue; }

      // 搜索老师id
      auto teacherId = [&] -> std::optional<std::string>
      {
        auto res = get
          ("/api/mentality/teachers/searchResults", {{"keyword", params.Name}});
        if (!res) return {};
        for (auto teach : YAML::Load(*res)["data"])
          if (teach["name"].as<std::string>() == params.Name)
            return log.rtn(teach["userId"].as<std::string>());
        log.error("teacher not found: {}"_f(params.Name));
        return {};
      }();
      if (!teacherId) continue;
      log.debug("found teacher id: {} -> {}"_f(params.Name, *teacherId));

      // 抓取排班表，在其中找到对应的时间段id
      auto timeId = [&] -> std::optional<int>
      {
        auto res = get
        (
          "/api/mentality/scheduling/page/week/users",
          {
            {"campus", Campus[params.Campus].first},
            {"type", Campus[params.Campus].second},
            {"dateStart", params.Date},
            {"dateEnd", params.Date}
          }
        );
        if (!res) return {};
        for (auto time : YAML::Load(*res)["data"])
          if (time["timeQuantumStart"].as<std::string>() == params.Time)
            return log.rtn(time["id"].as<int>());
        log.error("time slot not found: {}"_f(params.Time));
        return {};
      }();
      if (!timeId) continue;
      log.debug("found time id: {} -> {}"_f(params.Time, *timeId));

      // 提交增加排班的请求
      auto body = [&]
      {
        nlohmann::json j;
        j["campus"] = Campus[params.Campus].first;
        j["type"] = Campus[params.Campus].second;
        j["userId"] = *teacherId;
        j["isVisual"] = true;
        j["dayTimeIds"] = std::vector{*timeId};
        return log.rtn(j.dump());
      }();
      auto res = post("/api/mentality/scheduling/teachers", body);
      if (res) std::cout << *res << std::endl;
    }
    else log.error("unknown job type: {}"_f(job.Type));
  }
  return 0;
}
