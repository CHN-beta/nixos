# include <biu.hpp>
# include <tgbot/tgbot.h>
# include <slurm/slurm.h>
# include <slurm/slurmdb.h>
# include <boost/process.hpp>
# include <boost/process/v2.hpp>
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
    std::string token;
    std::map<std::string, std::string> user_map;
    std::string slurm_conf;
    std::map<std::string, std::string> context_map
    {
      { "prolog_slurmctld", "RUN" },
      { "epilog_slurmctld", "END" }
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
      if (!user_map.contains(user)) return;
      auto jid_cstr = std::getenv("SLURM_JOB_ID");
      if (!jid_cstr) throw std::runtime_error("SLURM_JOB_ID not found");
      jid = std::stoul(jid_cstr);
      auto context_cstr = std::getenv("SLURM_SCRIPT_CONTEXT");
      if (!context_cstr) throw std::runtime_error("SLURM_SCRIPT_CONTEXT not found");
      if (!context_map.contains(context_cstr)) throw std::runtime_error("unknown SLURM_SCRIPT_CONTEXT");
      context = context_cstr;
    }

    // 从 slurm 处查询信息
    YAML::Node info;
    {
      job_info_msg_t* job_info;
      slurm_init(slurm_conf.c_str());
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
        info["Partition"] = null_to_empty(job_info->job_array->partition);
        info["Submit Time"] = timepoint(job_info->job_array->submit_time);
        info["Start Time"] = timepoint(job_info->job_array->start_time);
        if (context == "epilog_slurmctld") info["End Time"] = timepoint(job_info->job_array->end_time);
        info["Nodes"] = null_to_empty(job_info->job_array->nodes);
        info["TREs Allocated"] = null_to_empty(job_info->job_array->tres_alloc_str);
        info["GREs Allocated"] = null_to_empty(job_info->job_array->gres_total);
        if (context == "epilog_slurmctld") info["Exit Code"] = job_info->job_array->exit_code;
        info["Status"] = get_status(job_info->job_array->job_state);
        info["Status"].SetStyle(YAML::EmitterStyle::Flow);
      }
      slurm_free_job_info_msg(job_info);
      slurm_fini();
    }

    // 从 slurmdbd 处查询信息
    // if (context == "epilog_slurmctld")
    // {
      // slurm_init(slurm_conf.c_str());
      // uint16_t conn_flags = 0;
      // auto conn = slurmdb_connection_get(&conn_flags);
      // if (!conn || errno != SLURM_SUCCESS) throw std::runtime_error("slurmdb_connection_get failed.");

      // 构造查询
      // slurmdb_job_cond_t* query = new slurmdb_job_cond_t;
      // query->step_list = slurm_list_create(slurm_destroy_selected_step);
      // slurm_selected_step_t* step = new slurm_selected_step_t;
      // step->step_id.step_het_comp = NO_VAL;
      // step->step_id.step_id = NO_VAL;
      // step->step_id.job_id = jid;
      // step->array_task_id = NO_VAL;
      // step->het_job_offset = NO_VAL;
      // step->array_bitmap = nullptr;
      // slurm_list_append(query->step_list, step);
      // // 查询
      // auto result = slurmdb_jobs_get(conn, query);
      // if (slurm_list_count(result) != 1) throw std::runtime_error("slurmdb_jobs_get failed.");
      // auto data = reinterpret_cast<slurmdb_job_rec_t*>(slurm_list_pop(result));
      // // 读取需要的信息并清理
      // slurm_list_destroy(result);
      // slurmdb_destroy_job_cond(query);
      // info["aaaa"] = data->uid;
      // slurmdb_destroy_job_rec(data);

      // auto close_result = slurmdb_connection_close(&conn);
      // if (close_result != SLURM_SUCCESS) throw std::runtime_error("slurmdb_connection_close failed.");
    // }

    // 发送消息
    {
      TgBot::Bot bot(token);
      std::stringstream ss;
      ss << "{} {} {}\n"_f(context, info["Job Id"], info["Job Name"]);
      ss << "<blockquote expandable>{}</blockquote>"_f(info);
      bot.getApi().sendMessage
        (user_map[user], ss.str(), nullptr, nullptr, nullptr, "HTML");
    }
  });
}

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

// int slurm_spank_job_epilog(spank_t spank, int ac, char** argv)
// {
//   using namespace biu::literals;
//   auto [info, outfile, uid, gid] = [&]
//   {
//     std::stringstream ss;
//     std::optional<std::string> outfile;
//     ss << "------------------------------------------------------------\n";
//     std::uint32_t jid, uid = -1, gid = -1;
//     auto result = spank_get_item(spank, S_JOB_ID, &jid);
//     if (result != ESPANK_SUCCESS) ss << "error getting job id: {}\n"_f(int(result));
//     else
//     {
//       ss << "info for job {}:\n"_f(jid);
//       YAML::Node info;
// 
//       // gather info from slurmctld
//       job_info_msg_t* job_info;
//       slurm_init(nullptr);
//       auto result = slurm_load_job(&job_info, jid, 0);
//       if (result != SLURM_SUCCESS) ss << "error loading job info: {}\n"_f(slurm_strerror(result));
//       else if (job_info->record_count != 1) ss << "record_count {} != 1\n"_f(job_info->record_count);
//       else
//       {
//         auto null_to_empty = [](const char* str) { return str ? str : ""; };
//         auto timepoint = [](time_t time)
//           { return "{:%Y-%m-%d %H:%M:%S}"_f(*std::localtime(&time)); };
//         auto timespan = [](time_t time)
//           { return "{:%H:%M:%S}"_f(std::chrono::seconds(time)); };
//         auto get_status = [](int code)
//           { return std::vector{ "{}"_f(job_states(code & 0xff)), "{:#x}"_f(code) }; };
//         info["Job Id"] = job_info->job_array->job_id;
//         info["Job Name"] = null_to_empty(job_info->job_array->name);
//         info["User Id"] = job_info->job_array->user_id;
//         info["Work Directory"] = null_to_empty(job_info->job_array->work_dir);
//         info["Output File"] = null_to_empty(job_info->job_array->std_out);
//         info["Partition"] = null_to_empty(job_info->job_array->partition);
//         info["Submit Time"] = timepoint(job_info->job_array->submit_time);
//         info["Start Time"] = timepoint(job_info->job_array->start_time);
//         info["End Time"] = timepoint(job_info->job_array->end_time);
//         info["Nodes"] = null_to_empty(job_info->job_array->nodes);
//         info["TREs Allocated"] = null_to_empty(job_info->job_array->tres_alloc_str);
//         info["GREs Allocated"] = null_to_empty(job_info->job_array->gres_total);
//         info["Exit Code"] = job_info->job_array->exit_code;
//         info["Status"] = get_status(job_info->job_array->job_state);
//         info["Status"].SetStyle(YAML::EmitterStyle::Flow);
//         info["Context"] = "{}"_f(spank_context());
//         info["Remote"] = spank_remote(spank);
//         if (job_info->job_array->std_out != nullptr) outfile = job_info->job_array->std_out;
//         uid = job_info->job_array->user_id;
//         gid = job_info->job_array->group_id;
//       }
//       slurm_free_job_info_msg(job_info);
//       slurm_fini();
// 
//       ss << "------------------------------------------------------------\n" << info << '\n';
//     }
//     return std::tuple(ss.str(), outfile, uid, gid);
//   }();
//   slurm_spank_log("%s", info.c_str());
//   if (outfile)
//   {
//     try
//     {
//       boost::asio::io_context context;
//       boost::system::error_code ec;
//       boost::asio::writable_pipe wp{context};
//       boost::process::v2::process proc
//       (
//         context, "/run/current-system/sw/bin/tee", { "-a", outfile->c_str() },
//         boost::process::v2::process_stdio{wp, nullptr, nullptr}, switch_user(uid, gid)
//       );
//       boost::asio::write(wp, boost::asio::buffer(info));
//       wp.close();
//       proc.wait();
//     }
//     catch (boost::system::system_error& e) { slurm_spank_log("boost error writing to output file: %s", e.what()); }
//     catch (std::exception& e) { slurm_spank_log("error writing to output file: %s", e.what()); }
//     catch (...) { slurm_spank_log("error writing to output file"); }
//   }
//   return 0;
// }
