# pragma once
# include <hpcstat/common.hpp>
# include <hpcstat/disk.hpp>

namespace hpcstat::sql
{
  struct LoginData
  {
    unsigned Id = 0; long Time;
    std::string Key, SessionId, Signature = "";
    std::optional<std::string> Subaccount, Ip;
    bool Interactive;
    using serialize = zpp::bits::members<8>;
    bool operator==(const LoginData& other) const = default;
  };
  struct LogoutData
  {
    unsigned Id = 0;
    long Time;
    std::string SessionId;
    bool operator==(const LogoutData& other) const = default;
  };
  struct SubmitJobData
  {
    unsigned Id = 0;
    long Time;
    unsigned JobId;
    std::string Key, SessionId, SubmitDir, JobCommand, Signature = "";
    std::optional<std::string> Subaccount, Ip;
    using serialize = zpp::bits::members<10>;
    bool operator==(const SubmitJobData& other) const = default;
  };
  struct FinishJobData
  {
    unsigned Id = 0;
    long Time;
    unsigned JobId;
    std::string JobResult, SubmitTime, JobDetail, Key, Signature = "";
    double CpuTime;
    using serialize = zpp::bits::members<9>;
    bool operator==(const FinishJobData& other) const = default;
  };
  struct CheckJobData
  {
    unsigned Id = 0;
    unsigned JobId;
    std::string Status;
    bool operator==(const CheckJobData& other) const = default;
  };
  struct DiskStatData
  {
    unsigned Id = 0;
    std::string Stat;
  };
  // 初始化数据库
  bool initdb();
  // 将数据写入数据库
  bool writedb(auto value);
  // 查询 bjobs -a 的结果中，有哪些是已经被写入到数据库中的（按照任务 id 和提交时间计算），返回未被写入的任务 id
  std::optional<std::set<unsigned>> finishjob_remove_existed(std::map<unsigned, std::string> jobid_submit_time);
  // 检查数据库中已经有的数据是否被修改过，如果有修改过，返回 std::nullopt，否则返回新增的数据，用于校验签名
  // 三个字符串分别是序列化后的数据，签名，指纹
  std::optional<std::vector<std::tuple<std::string, std::string, std::string>>>
    verify(std::string old_db, std::string new_db);
  // 将某个月份的数据导出到文件
  bool export_data(long start_time, long end_time, std::string filename);
  // 检查任务状态，返回有变化的任务 id、名称、现在的状态、提交时的 key、subaccount
  // 如果没有找到提交时的信息，则忽略这个任务
  std::optional<std::map<unsigned, std::tuple<std::string, std::string, std::string, std::optional<std::string>>>>
    check_job_status();
  // 返回最后一次检查磁盘占用的结果
  std::optional<disk::Usage> get_disk_stat();
}
