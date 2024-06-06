# pragma once
# include <optional>
# include <string>
# include <filesystem>
# include <vector>
# include <map>
# include <utility>
# include <set>
# include <iostream>
# include <regex>
# include <thread>
# include <chrono>
# include <fstream>
# include <future>
# include <fmt/format.h>
# include <date/date.h>
# include <date/tz.h>
# include <boost/interprocess/sync/file_lock.hpp>
# include <zpp_bits.h>

namespace hpcstat
{
  // run a program, wait until it exit, return its stdout if it return 0, otherwise nullopt
  std::optional<std::string> exec
  (
    std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin = std::nullopt,
    std::map<std::string, std::string> extra_env = {}
  );

  // get current time
  long now();

  // 序列化任意数据
  std::string serialize(auto data);

  // 反序列化任意数据
  template <typename T> T deserialize(std::string serialized_data);
}
