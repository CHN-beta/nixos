# include <hpcstat/common.hpp>
# include <hpcstat/sql.hpp>
# include <hpcstat/disk.hpp>

namespace hpcstat
{
  long now()
  {
    return std::chrono::duration_cast<std::chrono::seconds>
      (std::chrono::system_clock::now().time_since_epoch()).count();
  }
}
