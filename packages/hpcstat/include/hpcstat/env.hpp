# pragma once
# include <hpcstat/common.hpp>

namespace hpcstat::env
{
  // check if the program is running in an interactive shell
  bool interactive();

  // get the value of an environment variable
  std::optional<std::string> env(std::string name, bool required = false);

  // check if the program is running on a login node
  std::optional<bool> is_login_node();
}
