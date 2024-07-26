# include <boost/asio.hpp>
# include <winjob/windows.hpp>
# include <iostream>
# include <filesystem>
# include <fstream>

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

  boost::asio::io_context io_context;
  boost::asio::local::stream_protocol::endpoint ep(LR"(C:\ProgramData\winjob\winjobd.sock)");
  boost::asio::local::stream_protocol::acceptor acceptor(io_context, ep, false);
  winjob::set_permission(LR"(C:\ProgramData\winjob\winjobd.sock)");

  auto user = winjob::get_owner(LR"(C:\Users\chn\Desktop\winjob.exe)");
  if (user) winjob::run_as(*user, LR"(C:\Users\chn\Desktop\winjob.exe)");

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
