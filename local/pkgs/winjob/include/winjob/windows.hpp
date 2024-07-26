# include <optional>
# include <string>
# include <utility>

namespace winjob
{
  std::optional<std::pair<std::wstring, std::wstring>> get_owner(std::wstring file_name);
  bool set_permission(std::wstring fileName);
}
