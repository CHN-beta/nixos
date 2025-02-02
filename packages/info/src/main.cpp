# include <biu.hpp>
# include <boost/process.hpp>
# include <boost/process/v2.hpp>

extern "C"
{
# include <slurm/spank.h>
# include <slurm/slurm.h>
// ac argv: configuration count and flags in plugstack.conf
[[gnu::visibility("default")]] int slurm_spank_exit(spank_t spank, int ac, char** argv);
}

struct switch_user
{
  boost::system::error_code on_exec_setup(auto&&...)
  {
    // first set gid then set uid, otherwise failed
    if (setegid(1000) != 0 || seteuid(1000) != 0)
      return boost::system::error_code{errno, boost::system::system_category()};
    else return {};
    return {};
  }
};

int slurm_spank_exit(spank_t spank, int ac, char** argv)
{
  using namespace biu::literals;
  if (spank_context() == S_CTX_REMOTE)
  {
    std::stringstream ss;
    ss << "------------------------------------------------------------\n";
    std::uint32_t jid;
    auto result = spank_get_item(spank, S_JOB_ID, &jid);
    if (result != ESPANK_SUCCESS) ss << "error getting job id: {}\n"_f(int(result));
    else
    {
      ss << "info for job {}:\n"_f(jid);
      job_info_msg_t* job_info;
      // slurm_init(nullptr);
      auto result = slurm_load_job(&job_info, jid, 0);
      if (result != SLURM_SUCCESS) ss << "error loading job info: {}\n"_f(slurm_strerror(result));
      else if (job_info->record_count != 1) ss << "record_count {} != 1\n"_f(job_info->record_count);
      else
      {
        auto null_to_empty = [](const char* str) { return str ? str : ""; };
        auto timepoint = [](time_t time)
          { return "{:%Y-%m-%d %H:%M:%S}"_f(*std::localtime(&time)); };
        auto timespan = [](time_t time)
          { return "{:%H:%M:%S}"_f(std::chrono::seconds(time)); };
        YAML::Node info;
        info["Job Id"] = job_info->job_array->job_id;
        info["Job Name"] = null_to_empty(job_info->job_array->name);
        info["User Id"] = job_info->job_array->user_id;
        info["Work Directory"] = null_to_empty(job_info->job_array->work_dir);
        info["Partition"] = null_to_empty(job_info->job_array->partition);
        info["Submit Time"] = timepoint(job_info->job_array->submit_time);
        info["Start Time"] = timepoint(job_info->job_array->start_time);
        info["End Time"] = timepoint(job_info->job_array->end_time);
        info["Nodes"] = null_to_empty(job_info->job_array->nodes);
        info["TREs Allocated"] = null_to_empty(job_info->job_array->tres_alloc_str);
        info["GREs Allocated"] = null_to_empty(job_info->job_array->gres_total);
        info["Status"] = job_info->job_array->job_state;
        ss << "------------------------------------------------------------\n" << info;
      }
      slurm_free_job_info_msg(job_info);

      boost::asio::io_context context;
      boost::system::error_code ec;
      boost::asio::readable_pipe rp{context};
      boost::process::v2::process proc(context, "/run/current-system/sw/bin/capsh", { "--print" }, boost::process::v2::process_stdio{nullptr, rp, nullptr}, switch_user{});

      std::string output;
      boost::asio::read(rp, boost::asio::dynamic_buffer(output), ec);
      if (ec != boost::asio::error::eof) ss << "error reading whoami: {}\n"_f(ec.message());
      ss << "\nusername: {}"_f(output);
      proc.wait();
    }
    slurm_spank_log("%s", ss.str().c_str());
  }
  return 0;
}

[[gnu::visibility("default")]] extern const char* plugin_name;
[[gnu::visibility("default")]] extern const char* plugin_type;
[[gnu::visibility("default")]] extern const unsigned int plugin_version;
[[gnu::visibility("default")]] extern const unsigned int spank_plugin_version;
const char* plugin_name = "info";
const char* plugin_type = "spank";
const unsigned int plugin_version = SLURM_VERSION_NUMBER;
const unsigned int spank_plugin_version = 0;
