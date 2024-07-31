# include <future>
# include <utility>
# include <cstdio>
# include <biu.hpp>
# include <boost/process.hpp>
# include <boost/preprocessor.hpp>

namespace biu
{
  std::regex literals::operator""_re(const char* str, std::size_t len) { return std::regex{str, len}; }
  namespace common
  {
    void block_forever() { std::promise<void>().get_future().wait(); std::unreachable(); }
    bool is_interactive() { return isatty(fileno(stdin)); }
    std::optional<std::string> env(std::string name)
    {
      if (auto value = std::getenv(name.c_str()); !value) return std::nullopt;
      else return value;
    }

    template <detail_::ExecMode Mode> detail_::ExecResult<Mode>::operator bool() const { return ExitCode == 0; }

    template <detail_::ExecMode Mode> detail_::ExecResult<Mode> exec(detail_::ExecInput<Mode> input)
    {
      namespace bp = boost::process;

      // decide input/output format, prepare environment, seach actual program
      bp::ipstream stdout_stream, stderr_stream;
      bp::opstream input_stream;
      auto&& stdin_format = [&]
        { if constexpr (Mode.DirectStdin) return bp::std_in < stdin; else return bp::std_in < input_stream; }();
      auto&& stdout_format = [&]
        { if constexpr (Mode.DirectStdout) return bp::std_out > stdout; else return bp::std_out > stdout_stream; }();
      auto&& stderr_format = [&]
        { if constexpr (Mode.DirectStderr) return bp::std_err > stderr; else return bp::std_err > stderr_stream; }();
      auto&& actual_program = [&]
      {
        if constexpr (Mode.SearchPath) return bp::search_path(input.Program);
        else return input.Program.string();
      }();
      bp::environment env = boost::this_process::environment();
      for (const auto& [key, value] : input.ExtraEnv) env[key] = value;

      // start
      auto process = bp::child
        (actual_program, bp::args(input.Args), stdout_format, stderr_format, stdin_format, env);
      if constexpr (!Mode.DirectStdin) { input_stream << input.Stdin; input_stream.pipe().close(); }

      // wait for exit
      if (input.Timeout) { if (!process.wait_for(*input.Timeout)) process.terminate(); }
      else process.wait();

      // collect output
      detail_::ExecResult<Mode> result;
      result.ExitCode = process.exit_code();
      if constexpr (!Mode.DirectStdout) result.Stdout = {std::istreambuf_iterator<char>{stdout_stream.rdbuf()}, {}};
      if constexpr (!Mode.DirectStderr) result.Stderr = {std::istreambuf_iterator<char>{stderr_stream.rdbuf()}, {}};
      return result;
    }

#   define BIU_EXEC_PRED(r, i) BOOST_PP_NOT_EQUAL(i, 16)
#   define BIU_EXEC_OP(r, i) BOOST_PP_INC(i)
#   define BIU_EXEC_MACRO(r, i) \
    namespace detail_ \
      { constexpr ExecMode ExecMode##i {(i & 1) != 0, (i & 2) != 0, (i & 4) != 0, (i & 8) != 0}; } \
    template detail_::ExecResult<detail_::ExecMode##i>::operator bool() const; \
    template detail_::ExecResult<detail_::ExecMode##i> \
      exec<detail_::ExecMode##i>(detail_::ExecInput<detail_::ExecMode##i>);
    BOOST_PP_FOR(0, BIU_EXEC_PRED, BIU_EXEC_OP, BIU_EXEC_MACRO)
  }
}
