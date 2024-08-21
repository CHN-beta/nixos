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

    template <bool DirectStdout, bool DirectStderr>
      detail_::ExecResult<DirectStdout, DirectStderr>::operator bool() const
      { return ExitCode == 0; }
#   define BIU_EXECRESULT_PRED(r, state) BOOST_PP_NOT_EQUAL(state, 4)
#   define BIU_EXECRESULT_OP(r, state) BOOST_PP_INC(state)
#   define BIU_EXECRESULT_MACRO(r, state) \
      template detail_::ExecResult<(state & 1) != 0, (state & 2) != 0>::operator bool() const;
    BOOST_PP_FOR(0, BIU_EXECRESULT_PRED, BIU_EXECRESULT_OP, BIU_EXECRESULT_MACRO)
    namespace detail_
    {
      template <ExecInput Input>
        detail_::ExecResult<Input.DirectStdout, Input.DirectStderr> exec
      (
        std::conditional_t<Input.SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
        std::optional<std::string> stdin_string, std::map<std::string, std::string> extra_env
      )
      {
        namespace bp = boost::process;
        bp::ipstream stdout_stream, stderr_stream;
        bp::opstream input_stream;
        auto&& stdout_format = [&]
          { if constexpr (Input.DirectStdout) return bp::std_out > stdout; else return bp::std_out > stdout_stream; }();
        auto&& stderr_format = [&]
          { if constexpr (Input.DirectStderr) return bp::std_err > stderr; else return bp::std_err > stderr_stream; }();
        auto&& actual_program =
          [&]{ if constexpr (Input.SearchPath) return bp::search_path(program); else return program.string(); }();
        std::unique_ptr<bp::child> process;
        bp::environment env = boost::this_process::environment();
        for (const auto& [key, value] : extra_env) env[key] = value;
        process = [&]
        {
          if constexpr (Input.DirectStdin) return std::make_unique<bp::child>
            (actual_program, bp::args(args), stdout_format, stderr_format, bp::std_in < stdin, env);
          else if (stdin_string) return std::make_unique<bp::child>
            (actual_program, bp::args(args), stdout_format, stderr_format, bp::std_in < input_stream, env);
          else return std::make_unique<bp::child>
            (actual_program, bp::args(args), stdout_format, stderr_format, bp::std_in < bp::null, env);
        }();
        if (stdin_string) { input_stream << *stdin_string; input_stream.pipe().close(); }
        process->wait();
        return
        {
          .ExitCode = process->exit_code(),
          .Stdout = [&]
          {
            if constexpr (Input.DirectStdout) return Empty{};
            else return std::string{std::istreambuf_iterator<char>{stdout_stream.rdbuf()}, {}};
          }(),
          .Stderr = [&]
          {
            if constexpr (Input.DirectStderr) return Empty{};
            else return std::string{std::istreambuf_iterator<char>{stderr_stream.rdbuf()}, {}};
          }()
        };
      }
    }
    template <detail_::ExecInput Input> requires (!Input.DirectStdin)
      detail_::ExecResult<Input.DirectStdout, Input.DirectStderr> exec
    (
      std::conditional_t<Input.SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
      std::optional<std::string> stdin_string, std::map<std::string, std::string> extra_env
    )
      { return detail_::exec<Input>(program, args, stdin_string, extra_env); }
    template <detail_::ExecInput Input> requires (Input.DirectStdin)
      detail_::ExecResult<Input.DirectStdout, Input.DirectStderr> exec
    (
      std::conditional_t<Input.SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
      std::map<std::string, std::string> extra_env
    )
      { return detail_::exec<Input>(program, args, {}, extra_env); }
#   define BIU_EXEC_PRED(r, state) BOOST_PP_NOT_EQUAL(state, 8)
#   define BIU_EXEC_OP(r, state) BOOST_PP_INC(state)
#   define BIU_EXEC_MACRO(r, state) \
  template detail_::ExecResult<(state & 1) != 0, (state & 2) != 0> \
    exec<{false, (state & 1) != 0, (state & 2) != 0, (state & 4) != 0}> \
    (std::conditional_t<(state & 4) != 0, std::string, std::filesystem::path>, std::vector<std::string>, \
      std::optional<std::string>, std::map<std::string, std::string>); \
  template detail_::ExecResult<(state & 1) != 0, (state & 2) != 0> \
    exec<{true, (state & 1) != 0, (state & 2) != 0, (state & 4) != 0}> \
    (std::conditional_t<(state & 4) != 0, std::string, std::filesystem::path>, std::vector<std::string>, \
      std::map<std::string, std::string>);
    BOOST_PP_FOR(0, BIU_EXEC_PRED, BIU_EXEC_OP, BIU_EXEC_MACRO)
  }
}