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
# include <fmt/format.h>
# include <date/date.h>
# include <date/tz.h>
# include <boost/interprocess/sync/file_lock.hpp>
# include <zpp_bits.h>
# include <biu.hpp>

namespace hpcstat
{
  using namespace biu::literals;
  // get current time
  long now();

  // 序列化任意数据
  std::string serialize(auto data);

  // 反序列化任意数据
  template <typename T> T deserialize(std::string serialized_data);
}
