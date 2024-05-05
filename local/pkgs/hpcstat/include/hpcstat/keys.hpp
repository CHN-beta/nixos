# pragma once
# include <hpcstat/common.hpp>

namespace hpcstat
{
  // valid keys
  struct Key { std::string PubkeyFilename; std::string Username; };
  extern std::map<std::string, Key> Keys;
}
