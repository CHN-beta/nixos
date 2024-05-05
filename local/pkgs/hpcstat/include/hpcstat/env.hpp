# pragma once
# include <optional>
# include <string>

namespace hpcstat::env
{
  // check if the program is running in an interactive shell
  bool interactive();

  // get the value of an environment variable
  std::optional<std::string> env(std::string name, bool required = false);
}
