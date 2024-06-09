# pragma once
# include <biu/common.hpp>

namespace biu::env
{
  bool is_interactive();
  std::optional<std::string> env(std::string name);
}
