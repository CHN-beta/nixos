# include <iostream>
# include <hpcstat/env.hpp>
# include <fmt/format.h>
# include <unistd.h>

namespace hpcstat::env
{
  bool interactive() { return isatty(fileno(stdin)); }
  std::optional<std::string> env(std::string name, bool required)
  {
    if (auto value = std::getenv(name.c_str()); !value)
    {
      if (required) std::cerr << fmt::format("Failed to get environment variable {}\n", name);
      return std::nullopt;
    }
    else return value;
  }
}
