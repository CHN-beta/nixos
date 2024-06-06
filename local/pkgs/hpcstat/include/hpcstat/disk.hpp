# pragma once
# include <hpcstat/common.hpp>

namespace hpcstat::disk
{
  struct Usage
  {
    double Total;
    std::vector<std::pair<std::string, double>> Teacher;  // 已排序
    std::vector<std::pair<std::string, double>> Student;  // 已排序
    long Time;
    using serialize = zpp::bits::members<4>;
  };
  // 统计当前磁盘使用情况，并写入数据库
  bool stat(boost::interprocess::file_lock& lock);
}
