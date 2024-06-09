# include <future>
# include <utility>
# include <biu.hpp>
# include <boost/process.hpp>

namespace biu
{
  std::regex literals::operator""_re(const char* str, std::size_t len) { return std::regex{str, len}; }
  namespace common
  {
    void block_forever() { std::promise<void>().get_future().wait(); std::unreachable(); }
    detail_::ExecResult exec
    (
      std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin,
      std::map<std::string, std::string> extra_env
    )
    {
      namespace bp = boost::process;
      bp::ipstream stdout, stderr;
      bp::opstream input;
      std::unique_ptr<bp::child> process;
      bp::environment env = boost::this_process::environment();
      for (const auto& [key, value] : extra_env) env[key] = value;
      if (stdin)
      {
        process = std::make_unique<bp::child>
          (program.string(), bp::args(args), bp::std_out > stdout, bp::std_err > stderr,
            bp::std_in < input, env);
        input << *stdin;
        input.pipe().close();
      }
      else process = std::make_unique<bp::child>
        (program.string(), bp::args(args), bp::std_out > stdout, bp::std_err > stderr,
          bp::std_in < bp::null, env);
      process->wait();
      return
      {
        process->exit_code(),
        std::string{std::istreambuf_iterator<char>{stdout.rdbuf()}, {}},
        std::string{std::istreambuf_iterator<char>{stderr.rdbuf()}, {}}
      };
    }
  }

}
