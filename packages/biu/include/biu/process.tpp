# pragma once
# include <biu/process.hpp>
# include <biu/logger.hpp>
# include <biu/format.tpp>
# include <boost/process.hpp>
# include <boost/asio.hpp>

namespace biu::process
{
  template <detail_::ExecMode Mode> detail_::ExecResult<Mode>::operator bool() const { return ExitCode == 0; }

  template <detail_::ExecMode Mode, typename... Ts> detail_::ExecResult<Mode> exec
    (detail_::ExecInput<Mode> input, Ts&&... args)
  {
    Logger::Guard log;
    namespace bp = boost::process;
    boost::asio::io_context context;
    detail_::ExecResult<Mode> result;
    using namespace biu::literals;

    // seach actual program
    boost::filesystem::path actual_program = [&]
    {
      if constexpr (Mode.SearchPath) return bp::environment::find_executable(input.Program);
      else return input.Program.string();
    }();
    log.debug("Searching for program: {} -> {}"_f(input.Program, actual_program.string()));

    // env
    auto env = [&]
    {
      if constexpr (Mode.ModifyEnv)
      {
        auto current = bp::environment::current();
        std::unordered_map<bp::environment::key, bp::environment::value> env;
        for (const auto& e : current) env[e.key()] = e.value();
        for (const auto& [key, value] : input.ExtraEnv) env[key] = value;
        return env;
      }
      else return bp::environment::current();
    }();
    log();

    // io pipes
    std::optional<boost::asio::writable_pipe> stdin_pipe;
    std::optional<boost::asio::readable_pipe> stdout_pipe, stderr_pipe;
    bp::process_stdio stdio; // all io were set to Direct by default
    {
      if constexpr (Mode.Stdin == IoType::Close) stdio.in = nullptr;
      else if constexpr (Mode.Stdin == IoType::String)
      {
        stdio.in = stdin_pipe.emplace(context);
        boost::asio::async_write(*stdin_pipe, boost::asio::buffer(input.Stdin),
          [&](const boost::system::error_code&, std::size_t) { stdin_pipe->close(); });
      }
      if constexpr (Mode.Stdout == IoType::Close) stdio.out = nullptr;
      else if constexpr (Mode.Stdout == IoType::String)
      {
        stdio.out = stdout_pipe.emplace(context);
        boost::asio::async_read(*stdout_pipe, boost::asio::dynamic_buffer(result.Stdout), boost::asio::detached);
      }
      if constexpr (Mode.Stderr == IoType::Close) stdio.err = nullptr;
      else if constexpr (Mode.Stderr == IoType::String)
      {
        stdio.err = stderr_pipe.emplace(context);
        boost::asio::async_read(*stderr_pipe, boost::asio::dynamic_buffer(result.Stderr), boost::asio::detached);
      }
    }

    // start process
    Logger::try_exec([&]
    {
      auto proc = bp::process
        (context, actual_program, input.Args, std::move(stdio), std::move(env), std::forward<Ts>(args)...);
      std::optional<boost::asio::steady_timer> timeout;
      boost::asio::cancellation_signal sig;
      bp::async_execute
      (
        std::move(proc),
        boost::asio::bind_cancellation_slot
        (
          sig.slot(),
          [&](bp::v2::error_code ec, int exit_code) { result.ExitCode = exit_code; if (timeout) timeout->cancel(); }
        )
      );
      if constexpr (Mode.Timeout)
      {
        timeout.emplace(context, input.Timeout);
        timeout->async_wait([&](boost::system::error_code ec)
        {
          if (ec) return; // 定时器被取消（进程已正常退出）
          sig.emit(boost::asio::cancellation_type::partial);
          timeout->expires_after(input.Timeout);
          timeout->async_wait([&](boost::system::error_code ec2)
            { if (!ec2) sig.emit(boost::asio::cancellation_type::terminal); });
        });
      }

      context.run(); 
    });

    return result;
  }
}
