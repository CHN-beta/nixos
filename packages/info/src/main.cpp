# include <biu.hpp>
# include <boost/process.hpp>
# include <boost/process/v2.hpp>

extern "C"
{
# include <slurm/spank.h>
# include <slurm/slurm.h>
// ac argv: configuration count and flags in plugstack.conf
[[gnu::visibility("default")]] int slurm_spank_job_epilog(spank_t spank, int ac, char** argv);
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

int slurm_spank_job_epilog(spank_t spank, int ac, char** argv)
{
  using namespace biu::literals;
  auto [info, outfile, uid, gid] = [&]
  {
    std::stringstream ss;
    std::optional<std::string> outfile;
    ss << "------------------------------------------------------------\n";
    std::uint32_t jid, uid = -1, gid = -1;
    auto result = spank_get_item(spank, S_JOB_ID, &jid);
    if (result != ESPANK_SUCCESS) ss << "error getting job id: {}\n"_f(int(result));
    else
    {
      ss << "info for job {}:\n"_f(jid);
      YAML::Node info;

      // gather info from slurmctld
      job_info_msg_t* job_info;
      slurm_init(nullptr);
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
        auto get_status = [](int code)
          { return std::vector{ "{}"_f(job_states(code & 0xff)), "{:#x}"_f(code) }; };
        info["Job Id"] = job_info->job_array->job_id;
        info["Job Name"] = null_to_empty(job_info->job_array->name);
        info["User Id"] = job_info->job_array->user_id;
        info["Work Directory"] = null_to_empty(job_info->job_array->work_dir);
        info["Output File"] = null_to_empty(job_info->job_array->std_out);
        info["Partition"] = null_to_empty(job_info->job_array->partition);
        info["Submit Time"] = timepoint(job_info->job_array->submit_time);
        info["Start Time"] = timepoint(job_info->job_array->start_time);
        info["End Time"] = timepoint(job_info->job_array->end_time);
        info["Nodes"] = null_to_empty(job_info->job_array->nodes);
        info["TREs Allocated"] = null_to_empty(job_info->job_array->tres_alloc_str);
        info["GREs Allocated"] = null_to_empty(job_info->job_array->gres_total);
        info["Status"] = get_status(job_info->job_array->job_state);
        if (job_info->job_array->std_out != nullptr) outfile = job_info->job_array->std_out;
        uid = job_info->job_array->user_id;
        gid = job_info->job_array->group_id;
      }
      slurm_free_job_info_msg(job_info);
      slurm_fini();

      ss << "------------------------------------------------------------\n" << info << '\n';
    }
    return std::tuple(ss.str(), outfile, uid, gid);
  }();
  slurm_spank_log("%s", info.c_str());
  if (outfile)
  {
    try
    {
      boost::asio::io_context context;
      boost::system::error_code ec;
      boost::asio::writable_pipe wp{context};
      boost::process::v2::process proc
      (
        context, "/run/current-system/sw/bin/tee", { "-a", outfile->c_str() },
        boost::process::v2::process_stdio{wp, nullptr, nullptr}, switch_user(uid, gid)
      );
      boost::asio::write(wp, boost::asio::buffer(info));
      wp.close();
      proc.wait();
    }
    catch (boost::system::system_error& e) { slurm_spank_log("boost error writing to output file: %s", e.what()); }
    catch (std::exception& e) { slurm_spank_log("error writing to output file: %s", e.what()); }
    catch (...) { slurm_spank_log("error writing to output file"); }
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
