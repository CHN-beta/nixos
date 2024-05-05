# include <hpcstat/common.hpp>
# include <boost/process.hpp>

namespace hpcstat
{
  std::optional<std::string> exec
  (
    std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin,
    std::map<std::string, std::string> extra_env
  )
  {
    namespace bp = boost::process;
    bp::ipstream output;
    bp::opstream input;
    std::unique_ptr<bp::child> process;
    bp::environment env = boost::this_process::environment();
    for (const auto& [key, value] : extra_env) env[key] = value;
    if (stdin)
    {
      process = std::make_unique<bp::child>
        (program.string(), bp::args(args), bp::std_out > output, bp::std_err > stderr, bp::std_in < input, env);
      input << *stdin;
      input.pipe().close();
    }
    else process = std::make_unique<bp::child>
      (program.string(), bp::args(args), bp::std_out > output, bp::std_err > stderr, bp::std_in < bp::null, env);
    process->wait();
    if (process->exit_code() != 0) return std::nullopt;
    std::stringstream ss;
    ss << output.rdbuf();
    return ss.str();
  }
  long now()
  {
    return std::chrono::duration_cast<std::chrono::seconds>
      (std::chrono::system_clock::now().time_since_epoch()).count();
  }
}
