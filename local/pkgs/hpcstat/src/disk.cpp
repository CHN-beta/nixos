# include <hpcstat/disk.hpp>
# include <hpcstat/env.hpp>

namespace hpcstat::disk
{
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

  std::optional<Usage> stat()
  {
    if (auto homedir = env::env("HOME"); !homedir)
      { std::cerr << "HOME not set\n"; return {}; }
    else if (auto ducbindir = env::env("HPCSTAT_DUC_BINDIR"); !ducbindir)
      { std::cerr << "HPCSTAT_DUC_BINDIR not set\n"; return {}; }
    else if (auto datadir = env::env("HPCSTAT_DATADIR"); !datadir)
      { std::cerr << "HPCSTAT_DATADIR not set\n"; return {}; }
    else if
    (
      auto result = biu::exec<{.DirectStdout = true, .DirectStderr = true}>
      (
        // duc index -d ./duc.db -p ~
        "{}/duc"_f(*ducbindir),
        { "index", "-d", "{}/duc.db"_f(*datadir), "-p", *homedir }
      );
      !result
    )
      { std::cerr << "failed to index\n"; return {}; }
    else
    {
      auto get_size  = [&](std::optional<std::string> path) -> std::optional<double>
      {
        if
        (
          auto result = biu::exec
          (
            // duc ls -d ./duc.db -b -D /data/gpfs01/jykang/linwei/xxx
            "{}/duc"_f(*ducbindir),
            {
              "ls", "-d", "{}/duc.db"_f(*datadir), "-b", "-D",
              "{}{}{}"_f(*homedir, path ? "/" : "", path.value_or(""))
            }
          );
          !result
        )
          { std::cerr << "failed to ls {}\n"_f(path); return {}; }
        else
        {
          std::smatch match;
          if (!std::regex_search(result.Stdout, match, std::regex(R"((\d+))")))
            { std::cerr << "failed to parse {}\n"_f(result.Stdout); return std::nullopt; }
          return std::stod(match[1]) / 1024 / 1024 / 1024;
        }
      };
      auto get_subdir = [&](std::string path) -> std::vector<std::string>
      {
        std::filesystem::directory_iterator it(*homedir + "/" + path);
        std::vector<std::string> result;
        for (const auto& entry : it)
          if (entry.is_directory()) result.push_back(entry.path().filename().string());
        return result;
      };
      auto get_date = [&]() -> std::optional<std::string>
      {
        if
        (
          // duc info -d ./duc.db
          auto result = biu::exec
            ("{}/duc"_f(*ducbindir), { "info", "-d", "{}/duc.db"_f(*datadir) });
          !result
        )
          { std::cerr << "failed to get duc info\n"; return {}; }
        else
        {
          std::smatch match;
          // search string like 2024-06-08 13:45:19
          if (!std::regex_search(result.Stdout, match, std::regex(R"((\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}))")))
            { std::cerr << "failed to parse {}\n"_f(result.Stdout); return {}; }
          return match[1];
        }
      };
      Usage usage;
      if (auto size = get_size({})) usage.Total = *size; else return {};
      if (auto date = get_date()) usage.Time = *date; else return {};
      for (const auto& [dir, recursive] : Directories)
      {
        if (!std::filesystem::exists(*homedir + "/" + dir))
          { std::cerr << "{} does not exist\n"_f(*homedir + "/" + dir); continue; }
        if (auto size = get_size(dir)) usage.Teacher.push_back({ dir, *size });
        else return {};
        if (recursive) for (const auto& subdir : get_subdir(dir))
        {
          if (auto size = get_size(dir + "/" + subdir); size)
            usage.Student.push_back({ dir + "/" + subdir, *size });
          else return {};
        }
      }
      std::sort(usage.Teacher.begin(), usage.Teacher.end(),
        [](const auto& a, const auto& b) { return a.second > b.second; });
      std::sort(usage.Student.begin(), usage.Student.end(),
        [](const auto& a, const auto& b) { return a.second > b.second; });
      return usage;
    }
  }
}
