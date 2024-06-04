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
    auto all_size  = [&] -> std::optional<std::map<std::string, double>>
    {
      if
      (
        auto result =
          exec("/usr/bin/du", { "-a", "--max-depth=2", *homedir });
        !result
      )
        { std::cerr << fmt::format("failed to stat home.\n"); return std::nullopt; }
      else
      {
        std::map<std::string, double> size;
        std::regex re(R"((\d+)\s+(.*)\n)");
        for (auto i = std::sregex_iterator(result->begin(), result->end(), re);
          i != std::sregex_iterator(); ++i)
        {
          if (i->str(2).find(*homedir) != 0)
            { std::cerr << fmt::format("invalid path: {}\n", i->str(2)); return std::nullopt; }
          else size[i->str(2).substr(homedir->size())] = std::stoul(i->str(1)) / 1024. / 1024;
        }
        return size;
      }
    }();
    if (!all_size) return false;
    Usage usage;
    usage.Time = now();
    if (!all_size->contains("")) { std::cerr << "Failed to get size of home\n"; return false; }
    usage.Total = (*all_size)[""];
    for (const auto& [dir, recursive] : Directories)
    {
      if (!all_size->contains(dir))
        { std::cerr << fmt::format("Failed to get size of {}\n", dir); return false; }
      else usage.Teacher.push_back({ dir, (*all_size)[dir] });
      auto get_subdir = [](std::string path) -> std::vector<std::string>
      {
        std::filesystem::directory_iterator it(path);
        std::vector<std::string> result;
        for (const auto& entry : it)
          if (entry.is_directory()) result.push_back(entry.path().filename().string());
        return result;
      };
      if (recursive) for (const auto& subdir : get_subdir(*homedir + "/" + dir))
      {
        if (!all_size->contains(dir + "/" + subdir))
          { std::cerr << fmt::format("Failed to get size of {}/{}\n", dir, subdir); return false; }
        else usage.Student.push_back({ dir + "/" + subdir, (*all_size)[dir + "/" + subdir] });
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
