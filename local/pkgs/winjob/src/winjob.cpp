# include <boost/asio.hpp>
# include <iostream>

int main()
{
  boost::asio::io_context io_context;
  boost::asio::local::stream_protocol::endpoint ep("winjobd.sock");
  // send a message to the server
  boost::asio::local::stream_protocol::socket socket(io_context);
  socket.connect(ep);
  std::string message;
  std::getline(std::cin, message);
  boost::asio::write(socket, boost::asio::buffer(message));
  // receive a message from the server
  boost::asio::streambuf buf;
  boost::asio::read_until(socket, buf, '\n');
  std::istream is(&buf);
  std::string line;
  std::getline(is, line);
  std::cout << "Received: " << line << '\n';
  return 0;
}