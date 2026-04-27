# pragma once
# include <biu/common.hpp>
# include <boost/asio.hpp>

namespace biu
{
  namespace process
  {
    enum class IoType { Direct, Close, String };
    namespace detail_
    {
      struct ExecMode
      {
        bool SearchPath = false, ModifyEnv = false, Timeout = false;
        IoType Stdin = IoType::Direct, Stdout = IoType::Direct, Stderr = IoType::Direct;
      };
      template <ExecMode Mode> struct ExecResult
      {
        int ExitCode;
        boost::system::error_code BoostErrorCode;
        std::conditional_t<Mode.Stdout == IoType::String, std::string, Empty> Stdout;
        std::conditional_t<Mode.Stderr == IoType::String, std::string, Empty> Stderr;
        operator bool() const;
      };
      template <ExecMode Mode> struct ExecInput
      {
        std::conditional_t<Mode.SearchPath, std::string, std::filesystem::path> Program;
        std::vector<std::string> Args;
        std::conditional_t<Mode.Stdin == IoType::String, std::string, Empty> Stdin = {};
        std::conditional_t<Mode.ModifyEnv, std::map<std::string, std::string>, Empty> ExtraEnv = {};
        std::conditional_t<Mode.Timeout, std::chrono::milliseconds, Empty> Timeout = {};
      };
    }
    template <detail_::ExecMode Mode = {}, typename... Ts>
      detail_::ExecResult<Mode> exec(detail_::ExecInput<Mode> input, Ts&&... args);
  }
  using process::exec, process::IoType;
}
