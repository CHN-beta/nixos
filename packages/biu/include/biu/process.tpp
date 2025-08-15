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
    std::function<void(boost::asio::readable_pipe& p, std::string& result)> read_some =
      [&read_some](auto& p, auto& result)
      {
        auto buffer = std::make_shared<std::array<char, 1024>>();
        p.async_read_some
        (
          boost::asio::buffer(*buffer),
          [&, buffer](const boost::system::error_code& ec, std::size_t len)
          {
            Logger::Guard log;
            if (!ec) { result.append(buffer->data(), len); read_some(p, result); log.debug("read {}"_f(len)); }
            else log.debug("Error reading from pipe: {} {}"_f(ec.value(), ec.message()));
          }
        );
      };
    std::function<void(boost::asio::writable_pipe& p, std::string& result)> write_some =
      [&write_some](auto& p, auto& result)
      {
        if (result.empty()) { p.close(); return; }
        auto buffer = std::make_shared<std::array<char, 1024>>();
        std::copy(result.begin(), result.end(), buffer->begin());
        p.async_write_some
        (
          boost::asio::buffer(*buffer),
          [&, buffer](const auto& ec, std::size_t len)
          {
            Logger::Guard log;
            if (!ec) { result.erase(0, len); write_some(p, result); log.debug("write {}"_f(len)); }
            else log.debug("Error reading from pipe: {} {}"_f(ec.value(), ec.message()));
          }
        );
      };
    bp::process_stdio stdio
    {
      .in = [&] -> decltype(auto)
      {
        if constexpr (Mode.Stdin == IoType::Close) return nullptr;
        else if constexpr (Mode.Stdin == IoType::Direct)
          return decltype(bp::process_stdio::in)();
        else if constexpr (Mode.Stdin == IoType::String)
        {
          stdin_pipe = std::make_unique<boost::asio::writable_pipe>(context);
          write_some(*stdin_pipe, input.Stdin);
          return (*stdin_pipe);
        }
        else std::unreachable();
      }(),
      .out = [&] -> decltype(auto)
      {
        if constexpr (Mode.Stdout == IoType::Close) return nullptr;
        else if constexpr (Mode.Stdout == IoType::Direct)
          return decltype(bp::process_stdio::out)();
        else if constexpr (Mode.Stdout == IoType::String)
        {
          stdout_pipe = std::make_unique<boost::asio::readable_pipe>(context);
          read_some(*stdout_pipe, result.Stdout);
          return (*stdout_pipe);
        }
        else std::unreachable();
      }(),
      .err = [&] -> decltype(auto)
      {
        if constexpr (Mode.Stderr == IoType::Close) return nullptr;
        else if constexpr (Mode.Stderr == IoType::Direct)
          return decltype(bp::process_stdio::err)();
        else if constexpr (Mode.Stderr == IoType::String)
        {
          stderr_pipe = std::make_unique<boost::asio::readable_pipe>(context);
          read_some(*stderr_pipe, result.Stderr);
          return (*stderr_pipe);
        }
        else std::unreachable();
      }()
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
        context.run();
        finished.wait([](auto& v) { return v; });
      });
    }
    else
    {
      auto thread = std::thread([&]
      {
        Logger::try_exec([&]
        {
          auto proc = bp::process
            (context, actual_program, input.Args, std::move(stdio), std::move(env), std::forward<Ts>(args)...);
          proc.wait();
          result.ExitCode = proc.exit_code();
        });
      });
      context.run();
      thread.join();
    }
    return result;
  }
}
