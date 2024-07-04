# include <boost/asio.hpp>
# include <iostream>

int main()
{
  boost::asio::io_context io_context;
  boost::asio::local::stream_protocol::endpoint ep("/tmp/winjobd.sock");
  boost::asio::local::stream_protocol::acceptor acceptor(io_context, ep);
  auto getuid = [](boost::asio::local::stream_protocol::socket& socket)
  {
    struct ucred ucred;
    socklen_t len = sizeof(ucred);
    if (getsockopt(socket.native_handle(), SOL_SOCKET, SO_PEERCRED, &ucred, &len) == -1)
    {
      std::cerr << "Failed to get SO_PEERCRED\n";
      return 0u;
    }
    return ucred.uid;
  };
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
    std::cout << "Peer UID: " << getuid(socket) << '\n';
    // write a message to the client
    std::string message = "thanks for the message\n";
    boost::asio::write(socket, boost::asio::buffer(message));
    acceptor.async_accept(func);
  };
  acceptor.async_accept(func);
  io_context.run();
}
