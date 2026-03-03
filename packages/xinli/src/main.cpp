# include <biu.hpp>
# include <httplib.h>
# include <nlohmann/json.hpp>

using namespace biu::literals;

int main(int argc, char **argv)
{
  biu::Logger::Guard log;

# ifdef _WIN32
  SetConsoleOutputCP(65001);
# endif

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
  auto get_days = [](const std::array<std::string, 2> &date, unsigned dayOfWeek) -> std::vector<std::string>
  {
    std::vector<std::string> days;
    std::chrono::year_month_day start, end;
    std::istringstream(date[0]) >> std::chrono::parse("%Y-%m-%d", start);
    std::istringstream(date[1]) >> std::chrono::parse("%Y-%m-%d", end);
    for
    (
      auto day = start;
      day <= end;
      day = std::chrono::sys_days(day) + std::chrono::days{1}
    )
      if (std::chrono::weekday{day} == std::chrono::weekday{dayOfWeek})
        days.push_back(std::format("{:%Y-%m-%d}", day));
    return days;
  };
  auto get_teacher_id = [&](std::string name) -> std::optional<std::string>
  {
    auto res = get
      ("/api/mentality/teachers/searchResults", {{"keyword", name}});
    if (!res) return {};
    for (auto teach : YAML::Load(*res)["data"])
      if (teach["name"].as<std::string>() == name)
        return log.rtn(teach["userId"].as<std::string>());
    log.error("teacher not found: {}"_f(name));
    return {};
  };
  // 获取时间点的id，以及对应的老师排班，如果对应时间点有老师为隐藏排班则退出，要求手动处理
  auto get_time_id = [&]
  (
    std::array<std::string, 2> date, unsigned dayOfWeek, std::vector<std::string> time,
    std::string campus
  ) -> std::optional<std::map<int, std::vector<std::string>>>
  {
    std::map<int, std::vector<std::string>> result;
    for (auto day : get_days(date, dayOfWeek))
    {
      auto res = get
      (
        "/api/mentality/scheduling/page/week/users",
        {
          {"campus", Campus[campus].first},
          {"type", Campus[campus].second},
          {"dateStart", day},
          {"dateEnd", day}
        }
      );
      if (!res) { log.error("failed to fetch date: {}"_f(day)); return {}; }
      for (auto t : time)
      {
        bool timeFound = false;
        for (auto time : YAML::Load(*res)["data"])
          if (time["timeQuantumStart"].as<std::string>() == t)
          {
            // for (auto teacher : time["dayTimeTeacher"])
            //   if (!teacher["isVisual"].as<bool>())
            //     { log.error("hidden schedule found at {} {}"_f(day, t)); return {}; }
            result[time["id"].as<int>()] = {};
            for (auto teacher : time["dayTimeTeacher"])
              result[time["id"].as<int>()].push_back(teacher["user"]["teacherBaseInfo"]["userId"].as<std::string>());
            timeFound = true;
            break;
          }
        if (!timeFound) { log.error("time slot not found: {}"_f(t)); return {}; }
      }
    }
    return log.rtn(result);
  };

  for (const auto &job : Config.Jobs)
  {
    if (job.Type == "AddSchedule")
    {
      struct
      {
        std::string Campus, Name;
        std::array<std::string, 2> Date;
        std::vector<std::string> Time;
        unsigned DayOfWeek;
      } params;
      params = job.Params.as<decltype(params)>();
      if (!Campus.contains(params.Campus)) { log.error("unknown campus: {}"_f(params.Campus)); continue; }

      auto teacherId = get_teacher_id(params.Name);
      if (!teacherId) continue;
      log.info("found teacher id: {} -> {}"_f(params.Name, *teacherId));

      auto timeId = get_time_id(params.Date, params.DayOfWeek, params.Time, params.Campus);
      if (!timeId) continue;
      log.info("found time id: {} {} -> {}"_f(params.Date, params.Time, *timeId));

      std::cout << "Is this ok? press Enter to continue..." << std::flush;
      std::cin.get();

      // 提交增加排班的请求
      auto body = [&]
      {
        nlohmann::json j;
        j["campus"] = Campus[params.Campus].first;
        j["type"] = Campus[params.Campus].second;
        j["userId"] = *teacherId;
        j["isVisual"] = true;
        j["dayTimeIds"] = *timeId | ranges::views::keys | ranges::to_vector;
        return log.rtn(j.dump());
      }();
      auto res = post("/api/mentality/scheduling/teachers", body);
      if (res) std::cout << *res << std::endl;
    }
    else if (job.Type == "DelSchedule")
    {
      struct
      {
        std::string Campus, Name;
        std::array<std::string, 2> Date;
        std::vector<std::string> Time;
        unsigned DayOfWeek;
      } params;
      params = job.Params.as<decltype(params)>();
      if (!Campus.contains(params.Campus)) { log.error("unknown campus: {}"_f(params.Campus)); continue; }

      auto teacherId = get_teacher_id(params.Name);
      if (!teacherId) continue;
      log.info("found teacher id: {} -> {}"_f(params.Name, *teacherId));

      auto timeId = get_time_id
        (params.Date, params.DayOfWeek, params.Time, params.Campus);
      if (!timeId) continue;
      log.info("found time id: {} {} -> {}"_f(params.Date, params.Time, *timeId));

      std::cout << "Is this ok? press Enter to continue..." << std::flush;
      std::cin.get();

      for (auto id : *timeId)
      {
        // 检查该时间点是否有该老师的排班
        if (std::find(id.second.begin(), id.second.end(), *teacherId) == id.second.end())
        {
          log.info("no schedule found for teacher {} at time id {}"_f(*teacherId, id.first));
          continue;
        }
        // 检查该老师的排班是否被预约
        {
          auto res = get
          (
            "/api/mentality/scheduling/judgeStudentReservation",
            {
              {"dayTimeId", std::to_string(id.first)},
              {"deleteTeacherIds", *teacherId}
            }
          );
          if (!res)
          {
            log.error("failed to check reservation for teacher {} at time id {}"_f(*teacherId, id.first));
            continue;
          }
          if (YAML::Load(*res)["data"].as<bool>())
          {
            log.info("schedule for teacher {} at time id {} has been reserved"_f(*teacherId, id.first));
            continue;
          }
        }
        auto teachers = id.second | std::views::filter
          ([&](const std::string &x) { return x != *teacherId; }) | std::ranges::to<std::vector>();
        auto body = [&]
        {
          nlohmann::json j;
          j["dataTimeId"] = id.first;
          j["isUpdateNext"] = false;
          j["dayTimeTeachers"] = teachers | std::views::transform
            ([](const std::string &id)
              {
                nlohmann::json j;
                j["user"]["teacherBaseInfo"]["userId"] = id;
                return j;
              }
            ) | std::ranges::to<std::vector>();
          j["isVisual"] = true;
          return log.rtn(j.dump());
        }();
        auto res = post("/api/mentality/scheduling/dayTimeTeachers", body);
        if (res) std::cout << *res << std::endl;
        else log.error("failed to delete schedule for teacher {} at time id {}"_f(*teacherId, id.first));
      }
    }
    else log.error("unknown job type: {}"_f(job.Type));
  }
  return 0;
}
