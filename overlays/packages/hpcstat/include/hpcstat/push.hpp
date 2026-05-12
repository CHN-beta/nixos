# pragma once
# include <hpcstat/common.hpp>

namespace hpcstat::push
{
  // 向微信推送数据
  // 任务 id，名称、现在的状态、提交时的 key、subaccount
  bool push(std::map<unsigned, std::tuple<std::string, std::string, std::string, std::optional<std::string>>> data);
}
