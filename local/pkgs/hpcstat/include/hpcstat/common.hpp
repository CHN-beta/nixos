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
# include <fmt/format.h>

namespace hpcstat
{
  // run a program, wait until it exit, return its stdout if it return 0, otherwise nullopt
  std::optional<std::string> exec
    (std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin = std::nullopt);

  // get current time
  long now();
}