# include <hpcstat/env.hpp>
# include <unistd.h>

namespace hpcstat::env
{
  bool interactive() { return isatty(fileno(stdin)); }
  std::optional<std::string> env(std::string name, bool required)
  {
    if (auto value = std::getenv(name.c_str()); !value)
    {
      if (required) std::cerr << "Failed to get environment variable {}\n"_f(name);
      return std::nullopt;
    }
    else return value;
  }
}
