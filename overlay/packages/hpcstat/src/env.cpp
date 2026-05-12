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
  std::optional<bool> is_login_node()
  {
    char hostname[256];
    if (gethostname(hostname, sizeof(hostname)) == 0)
      if (std::string(hostname).starts_with("login")) return true;
      else return false;
    else return {};
  }
}
