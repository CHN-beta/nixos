# include <winjob/os.hpp>
# include <winjob/scheduler.hpp>
# include <nlohmann/json.hpp>
# include <iostream>
# include <filesystem>
# include <fstream>
# include <sstream>

using namespace std::literals;

int main()
{
# ifdef _WIN32
  std::filesystem::path datadir = R"(C:\ProgramData\winjob)";
# else
  std::filesystem::path datadir = ".";
# endif

  // ensure files and directories exist
  std::filesystem::create_directories(datadir);
  if (std::filesystem::exists(datadir / "winjobd.sock")) std::filesystem::remove(datadir / "winjobd.sock");
  std::ofstream log(datadir / "log.txt", std::ios::app);

  // setup scheduler
  winjob::Scheduler scheduler(nlohmann::json::parse(std::ifstream(datadir / "config.json"))["cpu"]);


  // setup connection
  // boost::asio::io_context io_context;
  // std::wstring endpoint = LR"(C:\ProgramData\winjob\winjobd.sock)";
  // boost::asio::local::stream_protocol::acceptor acceptor(io_context, endpoint, false);
  // winjob::set_permission(endpoint);
// 
  // std::function<void(const boost::system::error_code&, boost::asio::local::stream_protocol::socket)> func =
  //   [&](const boost::system::error_code& ec, boost::asio::local::stream_protocol::socket socket)
  //   {
  //     if (ec) log << "Failed to accept connection\n" << std::flush;
  //     else
  //     {
  //       log << "Accepted connection\n" << std::flush;
  //       boost::asio::streambuf buf;
  //       boost::asio::read_until(socket, buf, '\n');
  //       std::istream is(&buf);
  //       std::string line;
  //       std::getline(is, line);
  //       log << "Received: " << line << '\n' << std::flush;
  //       // write a message to the client
// 
// 
// 
// 
// 
  //       boost::asio::write(socket, boost::asio::buffer(message));
  //       acceptor.async_accept(func);
  //     }
  //     
// 
  //   };
  // acceptor.async_accept(func);
  // io_context.run();
// 
// 
// 
// 
  // auto user = winjob::get_owner(LR"(C:\Users\chn\Desktop\winjob.exe)");
  // if (!user)
  // {
  //   log << "Failed to get owner\n" << std::flush;
  //   return 1;
  // }
  // if (user)
  // {
  //   log << "Owner: " << user->first << "\\" << user->second << '\n' << std::flush;
  //   auto launcher = boost::process::v2::windows::with_logon_launcher(user->second, L"", user->first,
  //     LOGON_WITH_PROFILE);
  //   boost::asio::io_context ctx;
  //   boost::process::v2::error_code ec;
  //   std::wstring program = LR"(C:\Users\chn\Desktop\winjob.exe)";
  //   auto process = launcher(ctx, ec, program, std::vector<std::wstring>{});
  // }

}
