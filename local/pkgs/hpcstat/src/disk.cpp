# include <hpcstat/disk.hpp>
# include <hpcstat/env.hpp>
# include <hpcstat/sql.hpp>

// 需要统计的目录，是否统计子目录
std::map<std::string, bool> Directories =
{
  { "caiduanjun", true },
  { "Gaona", true },
  { "huangkai", true },
  { "huangshengli", false },
  { "kangjunyong", true },
  { "lijing", true },
  { "linwei", true },
  { "Lixu", true },
  { "wanghao", false },
  { "wuyaping", true },
  { "wuzhiming", true },
  { "zhanhuahan", false }
};

bool hpcstat::disk::stat(boost::interprocess::file_lock &lock)
{
  if (auto homedir = env::env("HOME"); !homedir)
    { std::cerr << "HOME not set\n"; return false; }
  else
  {
    auto get_size  = [](std::string path) -> std::optional<double>
    {
      if (auto result = exec("/usr/bin/du", { "-s", path }); !result)
        { std::cerr << fmt::format("failed to stat {}\n", path); return std::nullopt; }
      else
      {
        std::smatch match;
        if (!std::regex_search(*result, match, std::regex(R"((\d+))")))
          { std::cerr << fmt::format("failed to parse {}\n", *result); return std::nullopt; }
        return std::stod(match[1]) / 1024 / 1024;
      }
    };
    auto get_subdir = [](std::string path) -> std::vector<std::string>
    {
      std::filesystem::directory_iterator it(path);
      std::vector<std::string> result;
      for (const auto& entry : it)
        if (entry.is_directory()) result.push_back(entry.path().filename().string());
      return result;
    };
    Usage usage;
    usage.Time = now();
    if (auto size = get_size(*homedir); size) usage.Total = *size; else return false;
    for (const auto& [dir, recursive] : Directories)
    {
      if (auto size = get_size(*homedir + "/" + dir); size)
        usage.Teacher.push_back({ dir, *size });
      else return false;
      if (recursive) for (const auto& subdir : get_subdir(*homedir + "/" + dir))
      {
        if (auto size = get_size(*homedir + "/" + dir + "/" + subdir); size)
          usage.Student.push_back({ dir + "/" + subdir, *size });
        else return false;
      }
    }
    std::sort(usage.Teacher.begin(), usage.Teacher.end(),
      [](const auto& a, const auto& b) { return a.second > b.second; });
    std::sort(usage.Student.begin(), usage.Student.end(),
      [](const auto& a, const auto& b) { return a.second > b.second; });
    lock.lock();
    if (!sql::writedb(sql::DiskStatData{.Stat = serialize(usage),}))
      { std::cerr << "Failed to write to database\n"; return false; }
    return true;
  }
}
