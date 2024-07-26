# include <optional>
# include <string>
# include <utility>
# include <boost/process/v2.hpp>

namespace winjob
{
  std::optional<std::pair<std::wstring, std::wstring>> get_owner(std::wstring file_name);
  bool set_permission(std::wstring fileName);
  std::unique_ptr<boost::process::child> run_as(std::pair<std::wstring, std::wstring> user, std::wstring program);
}
