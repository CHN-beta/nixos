# pragma once
# include <boost/functional/hash.hpp>
# include <biu/common.hpp>
# include <boost/process.hpp>

namespace biu::common
{
  inline void unused(auto&&...) {}
  inline std::size_t hash(auto&&... objs)
  {
    std::size_t result = 0;
    (boost::hash_combine(result, objs), ...);
    return result;
  }

  template <typename String> inline constexpr bool CaseInsensitiveStringLessComparator::operator()
    (const String& s1, const String& s2) const
  {
    return std::lexicographical_compare
    (
      s1.begin(), s1.end(), s2.begin(), s2.end(),
      [](char c1, char c2){return std::tolower(c1) < std::tolower(c2);}
    );
  }
  template <bool directStdin, bool directStdout, bool directStderr, bool SearchPath>
    detail_::ExecResult<directStdout, directStderr> detail_::exec
  (
    std::conditional_t<SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
    std::optional<std::string> stdin, std::map<std::string, std::string> extra_env
  )
  {
    namespace bp = boost::process;
    bp::ipstream stdout_stream, stderr_stream;
    bp::opstream input_stream;
    auto&& stdout =
      [&]{ if constexpr (directStdout) return bp::std_out > ::stdout; else return bp::std_out > stdout_stream; }();
    auto&& stderr =
      [&]{ if constexpr (directStderr) return bp::std_err > ::stderr; else return bp::std_err > stderr_stream; }();
    auto&& actual_program =
      [&]{ if constexpr (SearchPath) return bp::search_path(program); else return program.string(); }();
    std::unique_ptr<bp::child> process;
    bp::environment env = boost::this_process::environment();
    for (const auto& [key, value] : extra_env) env[key] = value;
    process = [&]
    {
      if constexpr (directStdin) return std::make_unique<bp::child>
        (actual_program, bp::args(args), stdout, stderr, bp::std_in < ::stdin, env);
      else if (stdin) return std::make_unique<bp::child>
        (actual_program, bp::args(args), stdout, stderr, bp::std_in < input_stream, env);
      else return std::make_unique<bp::child>
        (actual_program, bp::args(args), stdout, stderr, bp::std_in < bp::null, env);
    }();
    if (stdin) { input_stream << *stdin; input_stream.pipe().close(); }
    process->wait();
    return
    {
      .exit_code = process->exit_code(),
      .stdout = [&]
      {
        if constexpr (directStdout) return Empty{};
        else return std::string{std::istreambuf_iterator<char>{stdout_stream.rdbuf()}, {}};
      }(),
      .stderr = [&]
      {
        if constexpr (directStderr) return Empty{};
        else return std::string{std::istreambuf_iterator<char>{stderr_stream.rdbuf()}, {}};
      }()
    };
  }
  template <bool DirectStdin, bool DirectStdout, bool DirectStderr, bool SearchPath> requires (!DirectStdin)
    detail_::ExecResult<DirectStdout, DirectStderr> exec
  (
    std::conditional_t<SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
    std::optional<std::string> stdin, std::map<std::string, std::string> extra_env
  )
    { return detail_::exec<DirectStdin, DirectStdout, DirectStderr, SearchPath>(program, args, stdin, extra_env); }
  template <bool DirectStdin, bool DirectStdout, bool DirectStderr, bool SearchPath> requires DirectStdin
    detail_::ExecResult<DirectStdout, DirectStderr> exec
  (
    std::conditional_t<SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
    std::map<std::string, std::string> extra_env
  )
    { return detail_::exec<DirectStdin, DirectStdout, DirectStderr, SearchPath>(program, args, {}, extra_env); }
}
