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
  template <bool directStdin, bool directStdout, bool directStderr> detail_::ExecResult<directStdout, directStderr> exec
  (
    std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin,
    std::map<std::string, std::string> extra_env
  )
  {
    namespace bp = boost::process;
    bp::ipstream stdout_stream, stderr_stream;
    bp::opstream input_stream;
    auto&& stdout =
      [&]{ if constexpr (directStdout) return bp::std_out > ::stdout; else return bp::std_out > stdout_stream; }();
    auto&& stderr =
      [&]{ if constexpr (directStderr) return bp::std_err > ::stderr; else return bp::std_err > stderr_stream; }();
    auto&& input = [&]
    {
      if constexpr (directStdin) return bp::std_in < ::stdin;
      else if (stdin) return bp::std_in < input_stream; else return bp::std_in < bp::null;
    }();
    std::unique_ptr<bp::child> process;
    bp::environment env = boost::this_process::environment();
    for (const auto& [key, value] : extra_env) env[key] = value;
    process = std::make_unique<bp::child>(program.string(), bp::args(args), stdout, stderr, input, env);
    if (stdin) { input << *stdin; input.pipe().close(); }
    process->wait();
    return
    {
      process->exit_code(),
      [&]
      {
        if constexpr (directStdout) return std::string{std::istreambuf_iterator<char>{stdout.rdbuf()}, {}};
        else return Empty{};
      }(),
      [&]
      {
        if constexpr (directStderr) return std::string{std::istreambuf_iterator<char>{stderr.rdbuf()}, {}};
        else return Empty{};
      }()
    };
  }
  template <bool DirectStdin, bool DirectStdout, bool DirectStderr> requires (!DirectStdin)
    detail_::ExecResult<DirectStdout, DirectStderr> exec
  (
    std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin,
    std::map<std::string, std::string> extra_env
  )
    { return exec<DirectStdout, DirectStderr>(program, args, stdin, extra_env); }
  template <bool DirectStdin, bool DirectStdout, bool DirectStderr> requires DirectStdin
    detail_::ExecResult<DirectStdout, DirectStderr> exec
  (
    std::filesystem::path program, std::vector<std::string> args, std::map<std::string, std::string> extra_env
  )
    { return exec<DirectStdin, DirectStdout, DirectStderr>(program, args, {}, extra_env); }
}
