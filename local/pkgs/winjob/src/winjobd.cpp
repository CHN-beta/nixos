# include <winjob/windows.hpp>
# include <boost/asio.hpp>
# include <boost/process/v2/windows/with_logon_launcher.hpp>
# include <boost/process/v2/process.hpp>
# include <iostream>
# include <filesystem>
# include <fstream>
# include <windows.h>

using namespace std::literals;

int main()
{
  // clear temp files
  std::filesystem::create_directories(LR"(C:\ProgramData\winjob)");
  if (std::filesystem::exists(LR"(C:\ProgramData\winjob\winjobd.sock)"))
    std::filesystem::remove(LR"(C:\ProgramData\winjob\winjobd.sock)");
  if (std::filesystem::exists(LR"(C:\ProgramData\winjob\auth)"))
    std::filesystem::remove(LR"(C:\ProgramData\winjob\auth)");
  std::filesystem::create_directories(LR"(C:\ProgramData\winjob\auth)");
  winjob::set_permission(LR"(C:\ProgramData\winjob\auth)");

  // log file
  std::ofstream log(LR"(C:\ProgramData\winjob\log.txt)", std::ios::app);

  auto user = winjob::get_owner(LR"(C:\Users\chn\Desktop\winjob.exe)");
  if (!user)
  {
    log << "Failed to get owner\n" << std::flush;
    return 1;
  }
  if (user)
  {
    log << "Owner: " << user->first << "\\" << user->second << '\n' << std::flush;
    auto launcher = boost::process::v2::windows::with_logon_launcher(user->second, L"", user->first,
      LOGON_WITH_PROFILE);
    boost::asio::io_context ctx;
    boost::process::v2::error_code ec;
    std::wstring program = LR"(C:\Users\chn\Desktop\winjob.exe)";
    auto process = launcher(ctx, ec, program, std::vector<std::wstring>{});
  }

  boost::asio::io_context io_context;
  boost::asio::local::stream_protocol::endpoint ep(R"(C:\ProgramData\winjob\winjobd.sock)");
  boost::asio::local::stream_protocol::acceptor acceptor(io_context, ep, false);
  winjob::set_permission(LR"(C:\ProgramData\winjob\winjobd.sock)");

  std::function<void(const boost::system::error_code&, boost::asio::local::stream_protocol::socket)> func =
    [&](const boost::system::error_code& ec, boost::asio::local::stream_protocol::socket socket)
  {
    if (ec)
    {
      log << "Failed to accept connection\n" << std::flush;
      return;
    }
    log << "Accepted connection\n" << std::flush;
    boost::asio::streambuf buf;
    boost::asio::read_until(socket, buf, '\n');
    std::istream is(&buf);
    std::string line;
    std::getline(is, line);
    log << "Received: " << line << '\n' << std::flush;
    // write a message to the client
    std::string message = "thanks for the message\n";
    boost::asio::write(socket, boost::asio::buffer(message));
    acceptor.async_accept(func);
  };
  acceptor.async_accept(func);
  io_context.run();
}
