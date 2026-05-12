# include <biu.hpp>
# include <tgbot/tgbot.h>
# ifndef INFO_CONFIG_FILE
#   define INFO_CONFIG_FILE "/etc/info.yaml"
# endif

int main()
{
  using namespace biu::literals;
  biu::Logger::init(std::make_shared<std::ofstream>("/var/log/slurmctld/info.log", std::ios::app),
    biu::Logger::Level::Info);
  biu::Logger::Guard log;
  biu::Logger::try_exec([]
  {
    // 读取配置
    struct
    {
      std::string token;
      std::map<std::string, std::string> user;
    } config;
    config = YAML::LoadFile(INFO_CONFIG_FILE).as<decltype(config)>();

    // 读取任务id和阶段id
    auto jobid_cstr = std::getenv("SLURM_JOB_ID");
    std::string jobid = jobid_cstr ? jobid_cstr : "unknown";
    auto stepid_cstr = std::getenv("SLURM_STEP_ID");
    std::string stepid = stepid_cstr ? stepid_cstr : "unknown";

    // 发送消息
    if (config.user.contains("root"))
    {
      TgBot::Bot bot(config.token);
      bot.getApi().sendMessage
      (
        config.user.at("root"), "Failed to kill {} {}"_f(jobid, stepid),
        nullptr, nullptr, nullptr, "HTML"
      );
    }
  });
}
