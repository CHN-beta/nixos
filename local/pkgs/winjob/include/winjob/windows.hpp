# include <optional>
# include <string>
# include <utility>

namespace winjob
{
  std::optional<std::pair<std::string, std::string>> get_owner(const std::string& file_name);
}
