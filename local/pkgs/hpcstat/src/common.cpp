# include <hpcstat/common.hpp>
# include <boost/filesystem.hpp>
# include <boost/process.hpp>
# include <boost/dll.hpp>

namespace hpcstat
{
  std::optional<std::string> exec
    (std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin)
  {
    namespace bp = boost::process;
    bp::ipstream output;
    bp::opstream input;
    std::unique_ptr<bp::child> process;
    if (stdin)
    {
      process = std::make_unique<bp::child>
        (program.string(), bp::args(args), bp::std_out > output, bp::std_err > stderr, bp::std_in < input);
      input << *stdin;
      input.pipe().close();
    }
    else process = std::make_unique<bp::child>
      (program.string(), bp::args(args), bp::std_out > output, bp::std_err > stderr, bp::std_in < bp::null);
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
