# pragma once
# include <optional>
# include <string>
# include <filesystem>
# include <vector>
# include <map>
# include <utility>
# include <set>
# include <iostream>
# include <regex>
# include <thread>
# include <chrono>
# include <fstream>
# include <future>
# include <date/date.h>
# include <date/tz.h>
# include <boost/interprocess/sync/file_lock.hpp>
# include <biu.hpp>

namespace hpcstat
{
  using namespace biu::literals;
  // get current time
  long now();
}
