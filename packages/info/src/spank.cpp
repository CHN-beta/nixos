# include <biu.hpp>

extern "C" {
# include <slurm/spank.h>

[[gnu::visibility("default")]] extern const char plugin_name [] = "info_spank";
[[gnu::visibility("default")]] extern const char plugin_type [] = "spank";
[[gnu::visibility("default")]] extern const unsigned int plugin_version = SLURM_VERSION_NUMBER;
[[gnu::visibility("default")]] extern const unsigned int spank_plugin_version = 1;

[[gnu::visibility("default")]] int slurm_spank_init(spank_t sp, int ac, char **argv);
[[gnu::visibility("default")]] int slurm_spank_local_user_init(spank_t sp, int ac, char **argv);
}

static bool silent_mode_enabled = false;

static int _silent_opt_cb(int val, const char *optarg, int remote) { silent_mode_enabled = true; return 0; }

static spank_option silent_opt =
{
  const_cast<char*>("silent"), nullptr,
  const_cast<char*>("Export SLURM_INFO_SILENT=1 for slurmctld-prolog/epilog"),
  0, 0, _silent_opt_cb
};

extern "C" int slurm_spank_init(spank_t sp, int ac, char **argv)
{
  if (spank_context() == S_CTX_LOCAL || spank_context() == S_CTX_ALLOCATOR)
    if (spank_option_register(sp, &silent_opt) != ESPANK_SUCCESS)
    {
      slurm_error("info_spank: Failed to register --silent option");
      return -1;
    }
  return 0;
}

extern "C" int slurm_spank_init_post_opt(spank_t sp, int ac, char **argv)
{
  if (silent_mode_enabled)
    if (spank_job_control_setenv(sp, "INFO_SILENT", "1", 1) != ESPANK_SUCCESS)
    {
      slurm_error("info_spank: Failed to set INFO_SILENT in job control environment");
      return -1;
    }
  return 0;
}
