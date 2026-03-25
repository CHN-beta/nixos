# include <biu.hpp>
# include <tgbot/tgbot.h>
# include <slurm/slurm.h>
# include <slurm/slurmdb.h>
# ifndef INFO_CONFIG_FILE
#   define INFO_CONFIG_FILE "/etc/info.yaml"
# endif

struct switch_user
{
  std::uint32_t uid, gid;
  switch_user(std::uint32_t uid, std::uint32_t gid) : uid(uid), gid(gid) {}
  boost::system::error_code on_exec_setup(auto&&...)
  {
    // first set gid then set uid, otherwise failed
    if (setegid(gid) != 0 || seteuid(uid) != 0)
      return boost::system::error_code{errno, boost::system::system_category()};
    else return {};
  }
};

int main()
{
  using namespace biu::literals;
  biu::Logger::init(std::make_shared<std::ofstream>("/var/log/slurmctld/info.log", std::ios::app),
    biu::Logger::Level::Info);
  biu::Logger::Guard log;
  biu::Logger::try_exec([]
  {
    // 读取配置
    std::string token;
    std::map<std::string, std::string> user_map;
    std::string slurm_conf;
    std::map<std::string, std::string> context_map
    {
      { "prolog_slurmctld", "Begin" },
      { "epilog_slurmctld", "End" }
    };
    {
      auto config = YAML::LoadFile(INFO_CONFIG_FILE);
      token = config["token"].as<std::string>();
      user_map = config["user"].as<std::map<std::string, std::string>>();
      slurm_conf = config["slurmConf"].as<std::string>();
    }

    // 读取用户名、任务 id、阶段
    std::string user;
    std::uint32_t jid;
    std::string context;
    {
      auto user_cstr = std::getenv("SLURM_JOB_USER");
      if (!user_cstr) throw std::runtime_error("SLURM_JOB_USER not found");
      user = user_cstr;
      auto jid_cstr = std::getenv("SLURM_JOB_ID");
      if (!jid_cstr) throw std::runtime_error("SLURM_JOB_ID not found");
      jid = std::stoul(jid_cstr);
      auto context_cstr = std::getenv("SLURM_SCRIPT_CONTEXT");
      if (!context_cstr) throw std::runtime_error("SLURM_SCRIPT_CONTEXT not found");
      if (!context_map.contains(context_cstr)) throw std::runtime_error("unknown SLURM_SCRIPT_CONTEXT");
      context = context_cstr;
    }

    YAML::Node info;
    std::uint32_t uid, gid;
    std::string output_file;
    // slurm 只能初始化一次，之后即使 fini 再初始化也会无法连接到数据库
    slurm_init(slurm_conf.c_str());

    // 从 slurm 处查询信息
    {
      job_info_msg_t* job_info;
      auto slurm_result = slurm_load_job(&job_info, jid, 0);
      if (slurm_result != SLURM_SUCCESS) throw std::runtime_error("slurm_load_job failed: {}"_f(slurm_strerror(slurm_result)));
      else if (job_info->record_count != 1) throw std::runtime_error("job_info->record_count != 1");
      else
      {
        auto null_to_empty = [](const char* str) { return str ? str : ""; };
        auto timepoint = [](time_t time)
          { return "{:%Y-%m-%d %H:%M:%S}"_f(*std::localtime(&time)); };
        auto get_status = [](int code)
          { return std::vector{ "{}"_f(job_states(code & 0xff)), "{:#x}"_f(code) }; };
        info["Job Id"] = job_info->job_array->job_id;
        info["Job Name"] = null_to_empty(job_info->job_array->name);
        info["Working Directory"] = null_to_empty(job_info->job_array->work_dir);
        info["Output File"] = null_to_empty(job_info->job_array->std_out);
        output_file = null_to_empty(job_info->job_array->std_out);
        info["Partition"] = null_to_empty(job_info->job_array->partition);
        info["Submit Time"] = timepoint(job_info->job_array->submit_time);
        info["Start Time"] = timepoint(job_info->job_array->start_time);
        if (context == "epilog_slurmctld") info["End Time"] = timepoint(job_info->job_array->end_time);
        // not working on epilog_slurmctld
        // info["Nodes"] = null_to_empty(job_info->job_array->nodes);
        info["Nodes"] = null_to_empty(std::getenv("SLURM_JOB_NODELIST"));
        info["TREs Allocated"] = null_to_empty(job_info->job_array->tres_alloc_str);
        info["GREs Allocated"] = null_to_empty(job_info->job_array->gres_total);
        if (context == "epilog_slurmctld") info["Exit Code"] = job_info->job_array->exit_code;
        info["Status"] = get_status(job_info->job_array->job_state);
        info["Status"].SetStyle(YAML::EmitterStyle::Flow);
        info["User ID"] = job_info->job_array->user_id;
        uid = job_info->job_array->user_id;
        info["Group ID"] = job_info->job_array->group_id;
        gid = job_info->job_array->group_id;
      }
      slurm_free_job_info_msg(job_info);
    }

    // 从 slurmdbd 处查询信息
    // 有问题，先不用这段代码
    // if (context == "epilog_slurmctld")
    if (false)
    {
      auto conn = slurmdb_connection_get(nullptr);
      if (!conn) throw std::runtime_error("slurmdb_connection_get failed.");

      // 构造查询
      // from: https://github.com/ksyx/turingopt/blob/20d88df423c0722839d1f0d185708da0af7c07a7/watcher/src/main.cpp#L329
      auto query = reinterpret_cast<slurmdb_job_cond_t*>
        (std::calloc(1, sizeof(slurmdb_job_cond_t)));
      query->flags |= JOBCOND_FLAG_NO_TRUNC;
      query->db_flags = SLURMDB_JOB_FLAG_NOTSET;
      query->step_list = slurm_list_create(slurm_destroy_selected_step);
      auto step = new slurm_selected_step_t
        {nullptr, NO_VAL, NO_VAL, {jid, NO_VAL, NO_VAL}};
      slurm_list_append(query->step_list, step);
      // 查询
      auto result = slurmdb_jobs_get(conn, query);
      if (slurm_list_count(result) != 1) throw std::runtime_error("slurmdb_jobs_get failed.");
      auto data = reinterpret_cast<slurmdb_job_rec_t*>(slurm_list_pop(result));
      // 读取需要的信息并清理
      slurm_list_destroy(result);
      slurmdb_destroy_job_cond(query);
      auto null_to_empty = [](const char* str) { return str ? str : ""; };
      info["Nodes"] = null_to_empty(data->nodes);
      slurmdb_destroy_job_rec(data);

      auto close_result = slurmdb_connection_close(&conn);
      if (close_result != SLURM_SUCCESS) throw std::runtime_error("slurmdb_connection_close failed.");
    }

    slurm_fini();

    // 发送消息
    if (auto silent = std::getenv("SPANK_INFO_SILENT"); !silent && user_map.contains(user))
    {
      TgBot::Bot bot(token);
      std::stringstream ss;
      ss << "<b>{}</b> {} {}\n"_f(context_map[context], info["Job Id"], info["Job Name"]);
      ss << "<blockquote expandable>{}</blockquote>"_f(info);
      bot.getApi().sendMessage
        (user_map[user], ss.str(), nullptr, nullptr, nullptr, "HTML");
    }

    // 写入消息
    if (context == "epilog_slurmctld" && !output_file.empty())
    {
      auto text = "\n--------------------\n{}\n--------------------\n"_f(info);
      biu::exec<{.Stdin = biu::IoType::String, .Stdout = biu::IoType::Close}>
      (
        {.Program = "/run/current-system/sw/bin/tee", .Args = { "-a", output_file }, .Stdin = text},
        switch_user(uid, gid)
      );
    }
  });
}
