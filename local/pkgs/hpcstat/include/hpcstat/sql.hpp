# pragma once
# include <set>
# include <zxorm/zxorm.hpp>
# include <zpp_bits.h>

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
  using LoginTable = zxorm::Table
  <
    "login", LoginData,
    zxorm::Column<"id", &LoginData::Id, zxorm::PrimaryKey<>>,
    zxorm::Column<"time", &LoginData::Time>,
    zxorm::Column<"key", &LoginData::Key>,
    zxorm::Column<"session_id", &LoginData::SessionId>,
    zxorm::Column<"signature", &LoginData::Signature>,
    zxorm::Column<"sub_account", &LoginData::Subaccount>,
    zxorm::Column<"ip", &LoginData::Ip>,
    zxorm::Column<"interactive", &LoginData::Interactive>
  >;
  struct LogoutData
  {
    unsigned Id = 0;
    long Time;
    std::string SessionId;
    bool operator==(const LogoutData& other) const = default;
  };
  using LogoutTable = zxorm::Table
  <
    "logout", LogoutData,
    zxorm::Column<"id", &LogoutData::Id, zxorm::PrimaryKey<>>,
    zxorm::Column<"time", &LogoutData::Time>,
    zxorm::Column<"sessionid", &LogoutData::SessionId>
  >;
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
  using SubmitJobTable = zxorm::Table
  <
    "submitjob", SubmitJobData,
    zxorm::Column<"id", &SubmitJobData::Id, zxorm::PrimaryKey<>>,
    zxorm::Column<"time", &SubmitJobData::Time>,
    zxorm::Column<"job_id", &SubmitJobData::JobId>,
    zxorm::Column<"key", &SubmitJobData::Key>,
    zxorm::Column<"session_id", &SubmitJobData::SessionId>,
    zxorm::Column<"submit_dir", &SubmitJobData::SubmitDir>,
    zxorm::Column<"job_command", &SubmitJobData::JobCommand>,
    zxorm::Column<"signature", &SubmitJobData::Signature>,
    zxorm::Column<"sub_account", &SubmitJobData::Subaccount>,
    zxorm::Column<"ip", &SubmitJobData::Ip>
  >;
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
  using FinishJobTable = zxorm::Table
  <
    "finishjob", FinishJobData,
    zxorm::Column<"id", &FinishJobData::Id, zxorm::PrimaryKey<>>,
    zxorm::Column<"time", &FinishJobData::Time>,
    zxorm::Column<"job_id", &FinishJobData::JobId>,
    zxorm::Column<"job_result", &FinishJobData::JobResult>,
    zxorm::Column<"submit_time", &FinishJobData::SubmitTime>,
    zxorm::Column<"job_detail", &FinishJobData::JobDetail>,
    zxorm::Column<"key", &FinishJobData::Key>,
    zxorm::Column<"signature", &FinishJobData::Signature>,
    zxorm::Column<"cpu_time", &FinishJobData::CpuTime>
  >;
  // 序列化任意数据，用于之后签名
  std::string serialize(auto data);
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
}
