# pragma once
# include <hpcstat/common.hpp>

namespace hpcstat::disk
{
  struct Usage
  {
    double Total;
    std::vector<std::pair<std::string, double>> Teacher;  // 已排序
    std::vector<std::pair<std::string, double>> Student;  // 已排序
    std::string Time;
    using serialize = zpp::bits::members<4>;
  };
  // 刷新 duc 数据库
  bool stat();
  // 从 duc 数据库中读取数据
  std::optional<Usage> get();
}
