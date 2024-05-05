# pragma once
# include <string>
# include <map>

namespace hpcstat
{
  // valid keys
  struct Key { std::string PubkeyFilename; std::string Username; };
  extern std::map<std::string, Key> Keys;
}
