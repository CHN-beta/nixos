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

    // 进程是在创建时就开始运行的，而不是在 io_context.run() 时才开始运行
    // 传入的 io_context 只是为了方便同步 io

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

    // prepare io pipes
    std::unique_ptr<boost::asio::writable_pipe> stdin_pipe;
    std::unique_ptr<boost::asio::readable_pipe> stdout_pipe, stderr_pipe;
    auto create_pipe_on_necessary = [&context]<typename T, IoType V>(auto& pipe) -> decltype(auto)
    {
      if constexpr (V == IoType::Close) return nullptr;
      else if constexpr (V == IoType::Direct) return T();
      else if constexpr (V == IoType::String)
      {
        pipe = std::make_unique<typename std::remove_reference_t<decltype(pipe)>::element_type>(context);
        return (*pipe);
      }
      else std::unreachable();
    };
    bp::process_stdio stdio
    {
      .in = create_pipe_on_necessary.template operator()
        <decltype(bp::process_stdio::in), Mode.Stdin>(stdin_pipe),
      .out = create_pipe_on_necessary.template operator()
        <decltype(bp::process_stdio::out), Mode.Stdout>(stdout_pipe),
      .err = create_pipe_on_necessary.template operator()
        <decltype(bp::process_stdio::err), Mode.Stderr>(stderr_pipe)
    };
    auto stdio_write = [&]
    {
      if constexpr (Mode.Stdin == IoType::String)
      {
        boost::asio::write(*stdin_pipe, boost::asio::buffer(input.Stdin));
        stdin_pipe->close();
      }
    };
    auto stdio_read = [&]
    {
      if constexpr (Mode.Stdout == IoType::String)
        boost::asio::read(*stdout_pipe, boost::asio::dynamic_buffer(result.Stdout));
      if constexpr (Mode.Stderr == IoType::String)
        boost::asio::read(*stderr_pipe, boost::asio::dynamic_buffer(result.Stderr));
    };
    log();

    // start process
    if constexpr (Mode.Timeout)
    {
      boost::asio::steady_timer timeout{context, input.Timeout};
      boost::asio::cancellation_signal sig;
      Atomic<bool> finished{false};
      Logger::try_exec([&]
      {
        auto proc = bp::process
          (context, actual_program, input.Args, std::move(stdio), std::move(env), std::forward<Ts>(args)...);
        bp::async_execute
        (
          std::move(proc),
          boost::asio::bind_cancellation_slot
          (
            sig.slot(),
            [&](bp::v2::error_code ec, int exit_code)
            {
              result.ExitCode = exit_code;
              timeout.cancel();
              finished = true;
            }
          )
        );
        timeout.expires_after(input.Timeout);
        timeout.async_wait([&](auto ec)
        {
          if (ec) return;
          sig.emit(boost::asio::cancellation_type::partial);
          timeout.expires_after(input.Timeout);
          timeout.async_wait
            ([&](auto ec) { if (!ec) sig.emit(boost::asio::cancellation_type::terminal); });
        });
        stdio_write();
        context.run();
        finished.wait([](auto& v) { return v; });
        stdio_read();
      });
    }
    else Logger::try_exec([&]
    {
      auto proc = bp::process
        (context, actual_program, input.Args, std::move(stdio), std::move(env), std::forward<Ts>(args)...);
      stdio_write();
      proc.wait();
      stdio_read();
      result.ExitCode = proc.exit_code();
    });
    return result;
  }
}
