# include <boost/asio.hpp>
# include <iostream>



int main()
{
  // clear temp files
  std::filesystem::create_directories(R"(C:\ProgramData\winjob)");
  if (std::filesystem::exists(R"(C:\ProgramData\winjob\winjobd.sock)"))
    std::filesystem::remove(R"(C:\ProgramData\winjob\winjobd.sock)");
  if (std::filesystem::exists(R"(C:\ProgramData\winjob\auth)"))
    std::filesystem::remove(R"(C:\ProgramData\winjob\auth)");
  std::filesystem::create_directories(R"(C:\ProgramData\winjob\auth)");

  // 


  

  boost::asio::io_context io_context;
  boost::asio::local::stream_protocol::endpoint ep(R"(C:\ProgramData\winjob\winjobd.sock)");
  boost::asio::local::stream_protocol::acceptor acceptor(io_context, ep, false);
  std::function<void(const boost::system::error_code&, boost::asio::local::stream_protocol::socket)> func =
    [&](const boost::system::error_code& ec, boost::asio::local::stream_protocol::socket socket)
  {
    if (ec)
    {
      std::cerr << "Failed to accept connection\n";
      return;
    }
    std::cout << "Accepted connection\n";
    boost::asio::streambuf buf;
    boost::asio::read_until(socket, buf, '\n');
    std::istream is(&buf);
    std::string line;
    std::getline(is, line);
    std::cout << "Received: " << line << '\n';
    // write a message to the client
    std::string message = "thanks for the message\n";
    boost::asio::write(socket, boost::asio::buffer(message));
    acceptor.async_accept(func);
  };
  acceptor.async_accept(func);
  io_context.run();
}
