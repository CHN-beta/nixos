# include <boost/process.hpp>
# include <boost/asio.hpp>
# include <iostream>
# include <format>

int main()
{
  namespace bp = boost::process;
  boost::asio::io_context context;
  boost::filesystem::path program = bp::environment::find_executable("echo");
  auto stdout_pipe = std::make_unique<boost::asio::readable_pipe>(context);
  std::string stdout_string;
  bp::process_stdio stdio{ .out = *stdout_pipe };
  auto proc = bp::process(context, program, { "hhh" }, bp::process_stdio(std::move(stdio)));
  std::print(std::cout, "process started\n");
  proc.wait();
  boost::system::error_code ec;
  boost::asio::read(*stdout_pipe, boost::asio::dynamic_buffer(stdout_string), ec);
  std::cout << std::format("{} {}\n", proc.exit_code(), stdout_string);
}
