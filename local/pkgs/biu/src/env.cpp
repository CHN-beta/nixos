# include <biu.hpp>
# include <boost/process.hpp>

namespace biu::env
{
  bool is_interactive() { return isatty(fileno(stdin)); }
  std::optional<std::string> env(std::string name)
  {
    if (auto value = std::getenv(name.c_str()); !value) return std::nullopt;
    else return value;
  }
}
